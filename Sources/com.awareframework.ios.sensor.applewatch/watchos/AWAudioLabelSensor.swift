//
//  AWAudioLabelSensor.swift
//  com.awareframework.ios.sensor.applewatch
//
//  Created by Yuuki Nishiyama on 2025/07/07.
//


import Foundation
import com_awareframework_ios_core
import com_awareframework_ios_sensor_applewatch_shared

public class AWAudioLabelSensor:AwareSensor {
    
    public var CONFIG = AWAudioSensor.Config()
    public init(_ config:AWAudioSensor.Config) {
        super.init()
        self.CONFIG = config
        self.CONFIG.dbTableName = AWAudioLabelData.databaseTableName
        self.CONFIG.dbPath = AWAudioLabelData.databaseTableName
        self.initializeDbEngine(config: self.CONFIG)
        super.syncConfig = DbSyncConfig().apply(closure: { config in
            config.serverType = self.CONFIG.serverType
            config.debug = self.CONFIG.debug
            config.batchSize = 1000
            config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.applewatch.audiolabel.sync.queue")
        })
        
        if let sqliteEngine = self.dbEngine as? SQLiteEngine {
            if let instance = sqliteEngine.getSQLiteInstance() {
                do {
                    try AWAudioLabelData.createTable(queue: instance)
                } catch {
                    if (CONFIG.debug) {
                        print(#function, error)
                    }
                }
            }
        }
    }
    
    /**
     * Start accelerometer sensor module
     */
    public override func start() {
       
    }

    /**
     * Stop accelerometer sensor module
     */
    public override func stop() {

    }

    /**
     * Sync accelerometer sensor module
     */
    public override func sync(force: Bool = false) {
        if let engine = self.dbEngine, let syncConfig = super.syncConfig {
            engine.startSync(syncConfig)
        }
    }
    
    /**
     * Set a label for a data
     */
    public override func set(label:String){
        
    }
}
