//
//  AWBatterySensor.swift
//  com.awareframework.ios.sensor.applewatch-watchOS
//
//  Created by Yuuki Nishiyama on 2022/12/31.
//

#if os(iOS)

#elseif os(watchOS)

import WatchKit
import com_awareframework_ios_core
import com_awareframework_ios_sensor_applewatch_shared

public class AWBatterySensor: AwareSensor, ObservableObject {

    @Published public var batteryLevels = [AWBatteryLinePoint]()

    var timer:Timer? = nil
    var isRunning = false
    
    let TAG = "AWARE::AppleWatch:battery"
    
    public var CONFIG = AWBatterySensor.Config()
    public class Config:SensorConfig{
        
        public var intervalSeconds = 60.0
        
        public override init(){
            super.init()
            self.dbTableName =  AWBatterySensorData.databaseTableName
            self.dbPath = AWBatterySensorData.databaseTableName
        }
        
        public override func set(config: Dictionary<String, Any>) {
            super.set(config: config)
        }
        
        public func apply(closure: (_ config: AWBatterySensor.Config ) -> Void) -> Self {
            closure(self)
            return self
        }
    }
    
    public init(_ config:AWBatterySensor.Config) {
        super.init()
        self.CONFIG = config
        self.initializeDbEngine(config: config)
        
        super.syncConfig = DbSyncConfig().apply(closure: { config in
            config.serverType = self.CONFIG.serverType
            config.debug = self.CONFIG.debug
            config.batchSize = 100
            config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.applewatch.battery.sync.queue")
        })
        
        if let sqliteEngine = self.dbEngine as? SQLiteEngine {
            if let queue = sqliteEngine.getSQLiteInstance() {
                do {
                    try AWBatterySensorData.createTable(queue: queue)
                }catch {
                    if (CONFIG.debug) { print(#function, error) }
                }
                
            }
        }
    }
    
    /**
                === basic functions ===
     */
    public override func start() {
        if (!isRunning) {
            WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
            isRunning = true
            startBatterySensors(interval: CONFIG.intervalSeconds)
        }
    }
    
    
    public override func stop(){
        if(isRunning) {
            stopBatterySensor()
            isRunning = false
        }
    }

    public override func sync(force: Bool = false) {
        if let engine = self.dbEngine, let syncConfig = super.syncConfig {
            engine.startSync(syncConfig)
        }
    }
    
    
    /*
     === special functions ===
     */
    private func startBatterySensors(interval:Double){
        
        // Configure a timer to fetch the data.
        if self.timer == nil {

            self.timer = Timer(fire: Date(), interval: TimeInterval(interval), repeats: true, block: { timer in
                let now = Date()
                
                let batteryLevel = Double(WKInterfaceDevice.current().batteryLevel)
                
                //                case unknown = 0
                //                case unplugged = 1 // on battery, discharging
                //                case charging = 2 // charging, less than 100%
                //                case full = 3 // charged, at 100%
                let batteryState = WKInterfaceDevice.current().batteryState
                
                self.batteryLevels.append(AWBatteryLinePoint(date: now, value: batteryLevel))
                if self.batteryLevels.count > 100 {
                    self.batteryLevels.removeFirst()
                }
                
                let data = AWBatterySensorData(timestamp: Int64(now.timeIntervalSince1970*1000),
                                                batteryLavel: batteryLevel,
                                                batteryState: batteryState.rawValue,
                                                label: self.CONFIG.label)
                self.dbEngine?.save([data])
                if (self.CONFIG.debug) {
                    print(self.TAG, now, batteryLevel, batteryState)
                }
            })
                
            // Add the timer to the current run loop.
            RunLoop.current.add(self.timer!, forMode: .default)
        }
    }

    private func stopBatterySensor(){
        if let t = self.timer {
            t.invalidate()
            self.timer = nil
        }
    }
    
}


public struct AWBatteryLinePoint {
    public var date: Date
    public var value: Double
}



#endif
