////
////  AWMotionSensor.swift
////  com.awareframework.ios.sensor.applewatch-watchOS
////
////  Created by Yuuki Nishiyama on 2022/12/17.
////
//
import WatchKit
import CoreMotion
import WatchConnectivity
import SwiftUI

public struct AWRotationLinePoint {
    public var date: Date
    public var x: Double
    public var y: Double
    public var z: Double
}

public struct AWAccelerationLinePoint {
    public var date: Date
    public var x:Double
    public var y:Double
    public var z:Double
}

public class AWMotionSensor: NSObject, ObservableObject {
    public var sensorData:AWMotionSensorData?

    let motion = CMMotionManager()
    let altimeter = CMAltimeter()

    var timer:Timer? = nil
    var lastBreakTime = Date()
    var isRunning = false
        
    let fileTransferManager = FileTransferManager()
    
    @Published public var accelerations = [AWAccelerationLinePoint]()
    @Published public var motions = [AWRotationLinePoint]()
    
    public var config = AWSensorConfig()
    
    func start(_ config:AWSensorConfig){
        if (!isRunning) {
            self.config = config
            isRunning = true
            sensorData = AWMotionSensorData()
            sensorData?.openFileHandler()
            startMotionSensors(hz: config.motionSensorHz)
        }
    }
    
    func stop(){
        if(isRunning) {
            stopMotionSensors()
            sensorData?.closeFileHandler()
            isRunning = false
        }
    }

    private func startMotionSensors(hz:Int){
        let interval = 1.0 / Double(hz)

        if self.motion.isAccelerometerAvailable{
            print("Start Acc sensors: interval = \(interval)")
            self.motion.accelerometerUpdateInterval = interval
            self.motion.startAccelerometerUpdates()
        }
        
        if self.motion.isGyroAvailable {
            print("Start Gyro sensors: interval = \(interval)")
            self.motion.gyroUpdateInterval = interval
            self.motion.startGyroUpdates()
        }

        if self.motion.isMagnetometerAvailable {
            print("Start Magnetometer sensor: interval = \(interval)")
            self.motion.magnetometerUpdateInterval = interval
            self.motion.startMagnetometerUpdates()
        }

        if self.motion.isDeviceMotionAvailable{
            print("Start Device Motion sensors: interval = \(interval)")
            self.motion.deviceMotionUpdateInterval = interval
            self.motion.startDeviceMotionUpdates()
            // self.motion.showsDeviceMovementDisplay = true
            // self.motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
        }
        
        if CMAltimeter.isAbsoluteAltitudeAvailable() {
            self.altimeter.startAbsoluteAltitudeUpdates(to: .main) { altitudeData, error in

            }
        }
        
        // Configure a timer to fetch the data.
        if self.timer == nil {

            lastBreakTime = Date()
            self.timer = Timer(fire: Date(), interval: interval,
                                repeats: true, block: { (timer) in
                
                let now = Date()
                
                
                if let acc = self.motion.accelerometerData {
                    self.accelerations.append(AWAccelerationLinePoint(date: now,
                                                                      x: acc.acceleration.x ,
                                                                      y: acc.acceleration.y,
                                                                      z: acc.acceleration.z))
                    if (self.accelerations.count > 100) {self.accelerations.removeFirst()}
                }
                
                if let deviceMotion = self.motion.deviceMotion {
                    self.motions.append(AWRotationLinePoint(date: now,
                                                          x: deviceMotion.rotationRate.x,
                                                          y: deviceMotion.rotationRate.y,
                                                          z: deviceMotion.rotationRate.z))
                    if (self.motions.count > 100) {self.motions.removeFirst()}
                }
            
                self.sensorData?.update(acc: self.motion.accelerometerData,
                                       deviceMotion: self.motion.deviceMotion,
                                       label: self.config.label)
                
                let gap = now.timeIntervalSince(self.lastBreakTime)
                if (gap > Double(self.config.autoFileTransferInterval) && self.config.autoFileTransfer){
                    if let data = self.sensorData {
                        data.closeFileHandler()
                        let originalFileURL = data.filePath
                        self.fileTransferManager.transferFile( fileURL: originalFileURL, debug: self.config.debug)
                    }
                    self.sensorData = AWMotionSensorData()
                    self.sensorData?.openFileHandler()
                    self.lastBreakTime = now
                }
            });

            // Add the timer to the current run loop.
            RunLoop.current.add(self.timer!, forMode: .default)
        }
    }

    
    private func getFileSize(path:String) -> UInt64 {
        do {
            let manager = FileManager.default
            let attributes = try manager.attributesOfItem(atPath: path) as NSDictionary
            return attributes.fileSize()
        }catch{
            return 0
        }

    }

    private func stopMotionSensors(){
        if self.motion.isAccelerometerAvailable{
            self.motion.stopAccelerometerUpdates()
            print("Stop Accelerometer sensor")
        }

        if self.motion.isDeviceMotionAvailable{
            self.motion.stopDeviceMotionUpdates()
            print("Stop Device Motion sensor")
        }
        
        if CMAltimeter.isAbsoluteAltitudeAvailable() {
            self.altimeter.stopAbsoluteAltitudeUpdates()
        }
        

        if let t = self.timer {
            t.invalidate()
            self.timer = nil
        }
        
        if let data = self.sensorData {
            self.fileTransferManager.transferFile(fileURL: data.filePath, debug: self.config.debug)
        }
    }
    
}

public class AWMotionSensorData: AWSensorData {

    public var acc:CMAccelerometerData?
    public var deviceMotion:CMDeviceMotion?
    public var label:String = ""
    
    init() {
        let header = ["timestamp","accx","accy","accz","roll","pitch","yaw",
                      "gravity-x","gravity-y","gravity-z","rotation-x","rotation-y","rotation-z",
                      "user-acc-x","user-acc-y","user-acc-z","label"]
        super.init("motion", header: header)
    }
    
    func update(acc: CMAccelerometerData?,
                deviceMotion: CMDeviceMotion?,
                label: String){
        self.acc = acc
        self.deviceMotion = deviceMotion
        self.label = label
        
        
        var values:[String] = []
        
        // set timestamp
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        values.append("\(now)")
        
        // set acc values
        if let acc = acc {
            values.append(contentsOf: [String(acc.acceleration.x), String(acc.acceleration.y), String(acc.acceleration.z)])
        }else{
            values.append(contentsOf: ["","",""])
        }

        // set motion values
        if let mot = deviceMotion{
            values.append(contentsOf: [
                String(mot.attitude.roll),String(mot.attitude.pitch),String(mot.attitude.yaw),
                String(mot.gravity.x), String(mot.gravity.y), String(mot.gravity.z),
                String(mot.rotationRate.x),String(mot.rotationRate.y),String(mot.rotationRate.z),
                String(mot.userAcceleration.x),String(mot.userAcceleration.y),String(mot.userAcceleration.z)
            ])
        }else{
            values.append(contentsOf: ["","","","","","","","","","","",""])
        }
        
        // set label
        values.append(label)
        
        self.save(values)
    }
    
}
