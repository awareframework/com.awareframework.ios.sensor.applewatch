//
//  AWDeviceSensor.swift
//  com.awareframework.ios.sensor.applewatch
//
//  Created by Yuuki Nishiyama on 2025/07/10.
//


#if os(iOS)

#elseif os(watchOS)

import com_awareframework_ios_core
import com_awareframework_ios_sensor_applewatch_shared
import Foundation
import WatchConnectivity


public class AWDeviceSensor: AwareSensor, ObservableObject {

//    @Published public var batteryLevels = [AWBatteryLinePoint]()
    
    let TAG = "AWARE::AppleWatch:device"
    
    private var session: WCSession?
    private var isSessionActivated = false
    
    public var CONFIG = AWDeviceSensor.Config()
    public class Config:SensorConfig{
        
        public var pairedDeviceIdReceivedHandler:((String)->Void)?
        
        public override init(){
            super.init()
            self.dbTableName =  AWDeviceSensorData.databaseTableName
            self.dbPath = AWDeviceSensorData.databaseTableName
        }
        
        public override func set(config: Dictionary<String, Any>) {
            super.set(config: config)
        }
        
        public func apply(closure: (_ config: AWDeviceSensor.Config ) -> Void) -> Self {
            closure(self)
            return self
        }
    }
    
    public init(_ config:AWDeviceSensor.Config) {
        super.init()
        self.CONFIG = config
        self.initializeDbEngine(config: config)
        AWWCSessionManager.shared
        
        super.syncConfig = DbSyncConfig().apply(closure: { config in
            config.serverType = self.CONFIG.serverType
            config.debug = self.CONFIG.debug
            config.batchSize = 100
            config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.applewatch.device.sync.queue")
        })
        
        if let sqliteEngine = self.dbEngine as? SQLiteEngine {
            if let queue = sqliteEngine.getSQLiteInstance() {
                do {
                    try AWDeviceSensorData.createTable(queue: queue)
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
        AWWCSessionManager.shared.getPairedDeviceId { deviceId in
            if (self.CONFIG.debug) {
                // watchOS と iOS では異なるdeviceIdが提供されているので、紐付けのために、スマートフォン側からdeviceIdを取り寄せる
                print(self.TAG, "iOS-> \(deviceId ?? ""), watchOS ->\(AwareUtils.getCommonDeviceId())")
            }
            
            if let did = deviceId as? String {
                if let engine = self.dbEngine as? SQLiteEngine{
                    let now = Date.now.timeIntervalSince1970 * 1000
                    let data = AWDeviceSensorData(timestamp: Int64(now),
                                                  pairedIosDeviceId: did,
                                                  label: self.CONFIG.label)
                    engine.save([data])
                }
                AWDeviceSensor.setPairedDeviceId(did)
                self.CONFIG.pairedDeviceIdReceivedHandler?(did)
            }
        }
    }
    
    
    public override func stop(){

    }

    public override func sync(force: Bool = false) {
        if let engine = self.dbEngine, let syncConfig = super.syncConfig {
            engine.startSync(syncConfig)
        }
    }
}

extension AWDeviceSensor {
    
    private static let kPairedDeviceIdKey:String = "com.aware.ios.sensor.core.key.paired_deviceid"
    
    public static func getPairedDeviceId() -> String? {
        if let deviceId = UserDefaults.standard.string(forKey: kPairedDeviceIdKey) {
            return deviceId
        }
        return nil
    }
    
    public static func setPairedDeviceId(_ deviceId:String) {
        UserDefaults.standard.set(deviceId, forKey: kPairedDeviceIdKey)
        UserDefaults.standard.synchronize()
    }
}


#endif
