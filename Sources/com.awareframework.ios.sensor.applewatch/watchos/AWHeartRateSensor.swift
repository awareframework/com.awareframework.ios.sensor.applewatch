//
//  AWHeartRateSensor.swift
//  com.awareframework.ios.sensor.applewatch-watchOS
//
//  Created by Yuuki Nishiyama on 2022/12/20.
//

#if os(iOS)


#elseif os(watchOS)

import WatchKit
import CoreMotion
import WatchConnectivity
import HealthKit

import com_awareframework_ios_core
import com_awareframework_ios_sensor_applewatch_shared


public class AWHeartRateSensor: AwareSensor, ObservableObject {
    
    @Published var sensorData:AWHeartRateSensorData?

    let healthStore = HKHealthStore()
    let heartRateUnit = HKUnit(from: "count/min")
    var hrMonitoringQuery:HKQuery?
        var lastBreakTime = Date()
    
    var isRunning = false
    
    @Published public var heartrates = [AWHeartRateLinePoint]()

    let TAG = "AWARE::AppleWatch:healthkit"
    
    public var CONFIG = AWHeartRateSensor.Config()
    public class Config:SensorConfig {
        public override init(){
            super.init()
            self.dbTableName = AWHeartRateSensorData.databaseTableName
            self.dbPath = AWHeartRateSensorData.databaseTableName
        }
        
        public override func set(config: Dictionary<String, Any>) {
            super.set(config: config)
        }
        
        public func apply(closure: (_ config: AWHeartRateSensor.Config ) -> Void) -> Self {
            closure(self)
            return self
        }
    }
    
    
    public init(_ config:AWHeartRateSensor.Config) {
        super.init()
        self.CONFIG = config
        self.initializeDbEngine(config: config)
        super.syncConfig = DbSyncConfig().apply(closure: { config in
            config.serverType = self.CONFIG.serverType
            config.debug = self.CONFIG.debug
            config.batchSize = 100
            config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.applewatch.healthkit.sync.queue")
        })
        
        if let sqliteEngine = self.dbEngine as? SQLiteEngine {
            if let queue = sqliteEngine.getSQLiteInstance() {
                do {
                    try AWHeartRateSensorData.createTable(queue: queue)
                }catch {
                    if (CONFIG.debug) { print(#function, error) }
                }
            }
        }
    }
    
    
    /**
     === basic function ===
     */
    
    
    public override func start(){
        if (!isRunning) {
            isRunning = true
            initHealthKit { state, error in
                if (state) {
                    if let query = self.createHeartRateStreamingQuery(Date()) {
                        self.hrMonitoringQuery = query
                        self.healthStore.execute(query)
                    }
                }
            }
        }
    }
    
    public override func stop(){
        if(isRunning) {
            isRunning = false
            if let query = self.hrMonitoringQuery{
                healthStore.stop(query)
                hrMonitoringQuery = nil
            }
        }
    }
    
    public override func sync(force: Bool = false) {
        if let engine = self.dbEngine, let syncConfig = super.syncConfig {
            engine.startSync(syncConfig)
        }
    }
    
    /**
        == special functions ==
     */
    
    
    func createHeartRateStreamingQuery(_ workoutStartDate: Date) -> HKQuery? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else { return nil }
//        HKQuantityTypeIdentifier.bodyTemperature
        let datePredicate = HKQuery.predicateForSamples(withStart: workoutStartDate, end: nil, options: .strictEndDate )
        //let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()])
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates:[datePredicate])


        let heartRateQuery = HKAnchoredObjectQuery(type: quantityType, predicate: predicate, anchor: nil, limit: Int(HKObjectQueryNoLimit)) { (query, sampleObjects, deletedObjects, newAnchor, error) -> Void in
            self.updateHeartRate(sampleObjects)
        }

        heartRateQuery.updateHandler = {(query, samples, deleteObjects, newAnchor, error) -> Void in
            self.updateHeartRate(samples)
        }
        return heartRateQuery
    }

    func updateHeartRate(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else {return}
        for sample in heartRateSamples {
            let now = Date()
            let hr = sample.quantity.doubleValue(for: self.heartRateUnit)
            
            let data = AWHeartRateSensorData(timestamp: Int64(now.timeIntervalSince1970 * 1000) ,
                                             hr: hr,
                                             label: self.CONFIG.label)
            self.dbEngine?.save([data])
            if (self.CONFIG.debug) {
                print(self.TAG, now, hr)
            }
            
            DispatchQueue.main.async {
                self.heartrates.append(AWHeartRateLinePoint(date: now, value: hr))
                if self.heartrates.count > 100 {
                    self.heartrates.removeFirst()
                }
            }
        }
    }
    
    
    func initHealthKit(completion: @escaping (Bool, Error?) -> Void){
        guard HKHealthStore.isHealthDataAvailable() == true else {
            return
        }
        guard let queryHeartRate = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else {
            return
        }
//        guard let queryheartRateVariabilitySDNN = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRateVariabilitySDNN) else {
//            return
//        }
        let dataTypes = Set(arrayLiteral: queryHeartRate )
        healthStore.requestAuthorization(toShare: nil,
                                         read: dataTypes) { (success, error) -> Void in
            completion(success, error)
        }
    }
}

public struct AWHeartRateLinePoint {
    public var date: Date
    public var value: Double
}

#endif
