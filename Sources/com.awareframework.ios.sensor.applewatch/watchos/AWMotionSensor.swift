////
////  AWMotionSensor.swift
////  com.awareframework.ios.sensor.applewatch-watchOS
////
////  Created by Yuuki Nishiyama on 2022/12/17.
////
//

#if os(iOS)
#elseif os(watchOS)
import WatchKit
#endif
import CoreMotion
import WatchConnectivity
import SwiftUI
import com_awareframework_ios_sensor_applewatch_shared
import com_awareframework_ios_core

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

public class AWMotionSensor: AwareSensor, ObservableObject {
    
    let motion = CMMotionManager()
    let altimeter = CMAltimeter()

    var dataBuffer: [AWMotionSensorData] = []
    
    var timer:Timer? = nil
    var lastBreakTime = Date()
    var isRunning = false
    
    @Published public var accelerations = [AWAccelerationLinePoint]()
    @Published public var motions = [AWRotationLinePoint]()
    
    let TAG = "AWARE::AppleWatch:motion"
    
    public var CONFIG = AWMotionSensor.Config()
    
    public class Config:SensorConfig{
                
        public var motionSensorHz  = 10
        public var saveIntervalSeconds = 10
        public var activateAccelerometerSensor = true
        public var activateGyroscopeSensor = true
        public var activateMagnetometerSensor = true
        public var activateDeviceMotionSensor = true
        
        public override init(){
            super.init()
            self.dbTableName =  AWMotionSensorData.databaseTableName
            self.dbPath = AWMotionSensorData.databaseTableName
        }
        
        public override func set(config: Dictionary<String, Any>) {
            super.set(config: config)
        }
        
        public func apply(closure: (_ config: AWMotionSensor.Config ) -> Void) -> Self {
            closure(self)
            return self
        }
    }
    
    public init(_ config:AWMotionSensor.Config) {
        super.init()
        self.CONFIG = config
        self.initializeDbEngine(config: config)
        
        super.syncConfig = DbSyncConfig().apply(closure: { config in
            config.serverType = self.CONFIG.serverType
            config.debug = self.CONFIG.debug
            config.batchSize = 1000
            config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.applewatch.motion.sync.queue")
            config.compactDataFormat = true
            config.progressHandler = { (_ progress:Double, _ error:Error?) in
                print(progress)
            }
        })
        
        if let sqliteEngine = self.dbEngine as? SQLiteEngine {
            if let queue = sqliteEngine.getSQLiteInstance() {
                do {
                    try AWMotionSensorData.createTable(queue: queue)
                }catch {
                    if (CONFIG.debug) {
                        print(#function, error)
                    }
                }
            }
        }
    }
    
    
    public override func start(){
        if (!isRunning) {
            isRunning = true
            startMotionSensors(hz: CONFIG.motionSensorHz)
        }
    }
    
    
    public override func stop(){
        if(isRunning) {
            stopMotionSensors()
            isRunning = false
        }
    }

    public override func sync(force: Bool = false) {
        if let engine = self.dbEngine, let syncConfig = super.syncConfig {
            engine.startSync(syncConfig)
        }
    }
    
    private func startMotionSensors(hz:Int){
        let interval = 1.0 / Double(hz)

        if CONFIG.activateAccelerometerSensor, self.motion.isAccelerometerAvailable{
            print(TAG, "Start Acc sensors: interval = \(interval)")
            self.motion.accelerometerUpdateInterval = interval
            self.motion.startAccelerometerUpdates()
        }
        
        if CONFIG.activateGyroscopeSensor, self.motion.isGyroAvailable {
            print(TAG, "Start Gyro sensors: interval = \(interval)")
            self.motion.gyroUpdateInterval = interval
            self.motion.startGyroUpdates()
        }

        if CONFIG.activateMagnetometerSensor, self.motion.isMagnetometerAvailable {
            print(TAG, "Start Magnetometer sensor: interval = \(interval)")
            self.motion.magnetometerUpdateInterval = interval
            self.motion.startMagnetometerUpdates()
        }

        if CONFIG.activateDeviceMotionSensor, self.motion.isDeviceMotionAvailable{
            print(TAG, "Start Device Motion sensors: interval = \(interval)")
            self.motion.deviceMotionUpdateInterval = interval
            self.motion.startDeviceMotionUpdates()
            // self.motion.showsDeviceMovementDisplay = true
            // self.motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
        }
        
//        if CMAltimeter.isAbsoluteAltitudeAvailable() {
//            self.altimeter.startAbsoluteAltitudeUpdates(to: .main) { altitudeData, error in
//                
//            }
//        }
        
        // Configure a timer to fetch the data.
        if self.timer == nil {

            lastBreakTime = Date()
            self.timer = Timer(fire: Date(), interval: interval,
                               repeats: true, block: { (timer) in
                
                let now = Date()
                
                if self.CONFIG.activateAccelerometerSensor || self.CONFIG.activateDeviceMotionSensor || self.CONFIG.activateGyroscopeSensor {
                    let acc = self.CONFIG.activateAccelerometerSensor ? self.motion.accelerometerData?.acceleration : nil
                    let motionData = self.CONFIG.activateDeviceMotionSensor ? self.motion.deviceMotion : nil
                    let rotation = self.CONFIG.activateGyroscopeSensor ? self.motion.gyroData?.rotationRate : nil
                    guard acc != nil || motionData != nil || rotation != nil else {
                        return
                    }
                    let data = AWMotionSensorData(timestamp: Int64(now.timeIntervalSince1970 * 1000),
                                                  accX: acc?.x ?? 0,
                                                  accY: acc?.y ?? 0,
                                                  accZ: acc?.z ?? 0,
                                                  roll: motionData?.attitude.roll ?? 0,
                                                  pitch: motionData?.attitude.pitch ?? 0,
                                                  yaw: motionData?.attitude.yaw ?? 0,
                                                  gravityX: motionData?.gravity.x ?? 0,
                                                  gravityY: motionData?.gravity.y ?? 0,
                                                  gravityZ: motionData?.gravity.z ?? 0,
                                                  rotationX: motionData?.rotationRate.x ?? rotation?.x ?? 0,
                                                  rotationY: motionData?.rotationRate.y ?? rotation?.y ?? 0,
                                                  rotationZ: motionData?.rotationRate.z ?? rotation?.z ?? 0,
                                                  userAccX: motionData?.userAcceleration.x ?? 0,
                                                  userAccY: motionData?.userAcceleration.y ?? 0,
                                                  userAccZ: motionData?.userAcceleration.z ?? 0,
                                                  label: self.CONFIG.label)
                    self.dataBuffer.append(data)
                }

                if self.CONFIG.activateAccelerometerSensor, let acc = self.motion.accelerometerData {
                    self.accelerations.append(AWAccelerationLinePoint(date: now,
                                                                      x: acc.acceleration.x ,
                                                                      y: acc.acceleration.y,
                                                                      z: acc.acceleration.z))
                    if (self.accelerations.count > 100) {self.accelerations.removeFirst()}
                }
                
                if self.CONFIG.activateDeviceMotionSensor, let deviceMotion = self.motion.deviceMotion {
                    self.motions.append(AWRotationLinePoint(date: now,
                                                            x: deviceMotion.rotationRate.x,
                                                            y: deviceMotion.rotationRate.y,
                                                            z: deviceMotion.rotationRate.z))
                    if (self.motions.count > 100) {self.motions.removeFirst()}
                }
                
                let gap = now.timeIntervalSince(self.lastBreakTime)
                if (gap > Double(self.CONFIG.saveIntervalSeconds)){
                    let dataArray = Array(self.dataBuffer)
                    OperationQueue().addOperation({ () -> Void in
                        self.dbEngine?.save(dataArray)
                        if (self.CONFIG.debug) {
                            print(self.TAG, "[Number of Records]", dataArray.count)
                            if (dataArray.count > 0) {
                                print(self.TAG , "[Last Record]", dataArray.last)
                            }
                        }
                    });
                    self.dataBuffer.removeAll()
                    self.lastBreakTime = now
                }
            });

            // Add the timer to the current run loop.
            RunLoop.current.add(self.timer!, forMode: .default)
        }
    }


    private func stopMotionSensors(){
        if self.motion.isAccelerometerActive {
            self.motion.stopAccelerometerUpdates()
            print(TAG, "Stop Accelerometer sensor")
        }

        if self.motion.isGyroActive {
            self.motion.stopGyroUpdates()
            print(TAG, "Stop Gyro sensor")
        }

        if self.motion.isMagnetometerActive {
            self.motion.stopMagnetometerUpdates()
            print(TAG, "Stop Magnetometer sensor")
        }

        if self.motion.isDeviceMotionActive {
            self.motion.stopDeviceMotionUpdates()
            print(TAG, "Stop Device Motion sensor")
        }
        
//        if CMAltimeter.isAbsoluteAltitudeAvailable() {
//            self.altimeter.stopAbsoluteAltitudeUpdates()
//        }
        

        if let t = self.timer {
            t.invalidate()
            self.timer = nil
        }
        
    }
}
