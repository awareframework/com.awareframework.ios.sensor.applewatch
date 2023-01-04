//
//  AWHealthKitSensor.swift
//  com.awareframework.ios.sensor.applewatch-watchOS
//
//  Created by Yuuki Nishiyama on 2022/12/20.
//

//import Foundation
import WatchKit
import CoreMotion
import WatchConnectivity
import HealthKit

public class AWHealthKitSensorData:AWSensorData {
    
    var hr:Double = 0.0
    
    init() {
        super.init("healthkit", header: ["timestamp", "hr", "label"])
    }
    
    func update(hr:Double, label:String = ""){
        self.hr = hr
        
        var values:[String] = []
        
        // set timestamp
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        values.append("\(now)")
        values.append("\(hr)")
        values.append(label)
        
        self.save(values)
    }
}

public struct AWHeartRateLinePoint {
    public var date: Date
    public var value: Double
}

public class AWHealthKitSensor: NSObject, ObservableObject {
    
    @Published var sensorData:AWHealthKitSensorData?

    let healthStore = HKHealthStore()
    let heartRateUnit = HKUnit(from: "count/min")
    var hrMonitoringQuery:HKQuery?
    
    var lastBreakTime = Date()
    
    var isRunning = false
    
    @Published public var heartrates = [AWHeartRateLinePoint]()
    
    let fileTransferManager = FileTransferManager()

    
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
    
    public var config = AWSensorConfig()
    
    func start(_ config:AWSensorConfig){
        self.config = config
        if (!isRunning) {
            isRunning = true
            sensorData = AWHealthKitSensorData()
            sensorData?.openFileHandler()
            if let query = createHeartRateStreamingQuery(Date()) {
                self.hrMonitoringQuery = query
                healthStore.execute(query)
            }
        }
    }
    
    func stop(){
        if(isRunning) {
            sensorData?.closeFileHandler()
            isRunning = false
            if let query = self.hrMonitoringQuery{
                healthStore.stop(query)
                hrMonitoringQuery = nil
            }
            if let sensorData = sensorData {
                fileTransferManager.transferFile(fileURL: sensorData.filePath, debug: self.config.debug)
            }

        }
    }
    
    func createHeartRateStreamingQuery(_ workoutStartDate: Date) -> HKQuery? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else { return nil }
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
            let hr = sample.quantity.doubleValue(for: self.heartRateUnit)
            self.sensorData?.update(hr: hr)
            
            DispatchQueue.main.async {
                let now = Date()
                let gap = now.timeIntervalSince(self.lastBreakTime)
                if (gap > Double(self.config.autoFileTransferInterval)){
                    if let sensorData = self.sensorData {
                        sensorData.closeFileHandler()
                        self.fileTransferManager.transferFile(fileURL: sensorData.filePath, debug: self.config.debug)
                    }
                    self.lastBreakTime = now
                    self.sensorData = AWHealthKitSensorData()
                    self.sensorData?.openFileHandler()
                }
                
                self.heartrates.append(AWHeartRateLinePoint(date: now, value: hr))
                if self.heartrates.count > 100 {
                    self.heartrates.removeFirst()
                    print(self.heartrates.count)
                }
            }
        }
    }
}
