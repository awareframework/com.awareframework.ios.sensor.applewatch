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

    var dataBuffer:Array<Dictionary<String,Any>>  = []
    
    var timer:Timer? = nil
    var lastBreakTime = Date()
    var isRunning = false
    
    @Published public var accelerations = [AWAccelerationLinePoint]()
    @Published public var motions = [AWRotationLinePoint]()
    
    let TAG = "AWARE::AppleWatch:motion"
    
    public var CONFIG = AWMotionSensor.Config()
    
    public class Config:SensorConfig{
                
        public var motionSensorHz  = 30
        public var saveIntervalSeconds = 10
        
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
        
        self.dbEngine?.dictToModelHandler = { (dict:Dictionary<String, Any>) -> Any  in
            return AWMotionSensorData(dict)
        }
        
        self.dbEngine?.modelToDictHandler = { (model:Any) -> Dictionary<String, Any>  in
            if let model = model as? AWMotionSensorData {
                return model.toDictionary()
            }
            return [:]
        }
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

        if self.motion.isAccelerometerAvailable{
            print(TAG, "Start Acc sensors: interval = \(interval)")
            self.motion.accelerometerUpdateInterval = interval
            self.motion.startAccelerometerUpdates()
        }
        
        if self.motion.isGyroAvailable {
            print(TAG, "Start Gyro sensors: interval = \(interval)")
            self.motion.gyroUpdateInterval = interval
            self.motion.startGyroUpdates()
        }

        if self.motion.isMagnetometerAvailable {
            print(TAG, "Start Magnetometer sensor: interval = \(interval)")
            self.motion.magnetometerUpdateInterval = interval
            self.motion.startMagnetometerUpdates()
        }

        if self.motion.isDeviceMotionAvailable{
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
                
                if let accData = self.motion.accelerometerData,
                   let motionData = self.motion.deviceMotion{
                    let data = AWMotionSensorData(timestamp: Int64(accData.timestamp*1000.0),
                                                  accX: accData.acceleration.x,
                                                  accY: accData.acceleration.y,
                                                  accZ: accData.acceleration.z,
                                                  roll: motionData.attitude.roll,
                                                  pitch: motionData.attitude.pitch,
                                                  yaw: motionData.attitude.yaw,
                                                  gravityX: motionData.gravity.x,
                                                  gravityY: motionData.gravity.y,
                                                  gravityZ: motionData.gravity.z,
                                                  rotationX: motionData.rotationRate.x,
                                                  rotationY: motionData.rotationRate.y,
                                                  rotationZ: motionData.rotationRate.z,
                                                  userAccX: motionData.userAcceleration.x,
                                                  userAccY: motionData.userAcceleration.y,
                                                  userAccZ: motionData.userAcceleration.z,
                                                  label: self.CONFIG.label)
                    self.dataBuffer.append(data.toDictionary())
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
        if self.motion.isAccelerometerAvailable{
            self.motion.stopAccelerometerUpdates()
            print(TAG, "Stop Accelerometer sensor")
        }

        if self.motion.isDeviceMotionAvailable{
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
