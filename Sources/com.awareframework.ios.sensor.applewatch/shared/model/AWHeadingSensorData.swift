//
//  AWHeadingSensorData.swift
//  com.awareframework.ios.sensor.applewatch
//
//  Created by Yuuki Nishiyama on 2025/07/08.
//

import Foundation
import com_awareframework_ios_core
import GRDB

public struct AWHeadingSensorData: BaseDbModelSQLite {

    

    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "watchOS"
    public var jsonVersion: Int = 1

    public var id: Int64?
    public var timestamp: Int64
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label:String = ""

    public static let tableName = "watch_heading"

    public var trueHeading: Double
    public var magneticHeading: Double
    public var headingAccuracy: Double
    public var x: Double
    public var y: Double
    public var z: Double

    public init(timestamp : Int64,
                trueHeading: Double,
                magneticHeading: Double,
                headingAccuracy: Double,
                x: Double,
                y: Double,
                z: Double) {
        self.timestamp = timestamp
        self.trueHeading = trueHeading
        self.magneticHeading = magneticHeading
        self.headingAccuracy = headingAccuracy
        self.x = x
        self.y = y
        self.z = z
    }

    public init(_ dict: Dictionary<String, Any>) {
        self.timestamp = dict["timestamp"] as? Int64 ?? 0
        self.deviceId = dict["deviceId"] as? String ?? AwareUtils.getCommonDeviceId()
        self.trueHeading = dict["trueHeading"] as? Double ?? 0.0
        self.magneticHeading = dict["magneticHeading"] as? Double ?? 0.0
        self.headingAccuracy = dict["headingAccuracy"] as? Double ?? 0.0
        self.x = dict["x"] as? Double ?? 0.0
        self.y = dict["y"] as? Double ?? 0.0
        self.z = dict["z"] as? Double ?? 0.0
        self.label = dict["label"] as? String ?? ""
    }
    
    
    public static func createTable(queue: GRDB.DatabaseQueue ) throws {
        try queue.write { db in
            try db.create(table: AWHeadingSensorData.tableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .integer).notNull()
                t.column("device_id", .text).notNull()
                t.column("label", .text).notNull()
                t.column("true_heading", .double).notNull()
                t.column("magnetic_heading", .double).notNull()
                t.column("heading_accuracy", .double).notNull()
                t.column("x", .double).notNull()
                t.column("y", .double).notNull()
                t.column("z", .double).notNull()
            }
        }
    }

    public func toDictionary() -> [String: Any] {
        return [
            "id": id ?? -1,
            "timestamp": timestamp,
            "deviceId": deviceId,
            "trueHeading": trueHeading,
            "magneticHeading": magneticHeading,
            "headingAccuracy": headingAccuracy,
            "x": x,
            "y": y,
            "z": z,
            "label": label,
        ]
    }

}

//public class AWHeadingSensorData:AWSensorData {
//
//    init() {
//        super.init("heading", header: ["timestamp",
//                                       "true_heading",
//                                       "magnetic_heading",
//                                       "heading_accuracy",
//                                       "x",
//                                       "y",
//                                       "z",
//                                       "label"])
//    }
//
//    func update(_ heading: CLHeading, label:String = ""){
//
//        var values:[String] = []
//
//        // set timestamp
//        let now = Int64(heading.timestamp.timeIntervalSince1970 * 1000)
//        values.append(String(now))
//
//        values.append(contentsOf: [
//            String(heading.trueHeading),
//            String(heading.magneticHeading),
//            String(heading.headingAccuracy),
//            String(heading.x),
//            String(heading.y),
//            String(heading.z)
//        ])
//
//        values.append(label)
//
//        self.save(values)
//    }
//}
