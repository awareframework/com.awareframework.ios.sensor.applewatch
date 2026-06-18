//
//  AWHeartRateData.swift
//  com.awareframework.ios.sensor.applewatch
//
//  Created by Yuuki Nishiyama on 2025/07/08.
//

import com_awareframework_ios_core
import GRDB

public struct AWHeartRateSensorData: BaseDbModelSQLite {
    
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "watchOS"
    public var jsonVersion: Int = 1
    
    public var id: Int64?
    public var timestamp: Int64
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String

    public static let databaseTableName = "ios_watch_heart_rate"

    public var hr:Double = 0.0
    
    public init(timestamp: Int64, hr: Double, label: String = "") {
        self.timestamp = timestamp
        self.hr = hr
        self.label = label
    }

    public init(_ dict: Dictionary<String, Any>) {
        self.timestamp = dict["timestamp"] as? Int64 ?? 0
        self.deviceId = dict["deviceId"] as? String
            ?? dict["device_id"] as? String
            ?? AwareUtils.getCommonDeviceId()
        self.hr = dict["hr"] as? Double ?? 0.0
        self.label = dict["label"] as? String ?? ""
    }
    
    public func toDictionary() -> Dictionary<String, Any> {
        return [
            "id" : self.id ?? -1,
            "timestamp": self.timestamp,
            "deviceId": self.deviceId,
            "hr": self.hr,
            "label": self.label
        ]
    }

    public static func createTable(queue: GRDB.DatabaseQueue) throws {
        try queue.write { db in
            try db.create(table: AWHeartRateSensorData.databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .integer).notNull()
                t.column("deviceId", .text).notNull()
                t.column("hr", .double).notNull()
                t.column("os", .text).notNull()
                t.column("timezone", .integer).notNull()
                t.column("jsonVersion", .integer).notNull()
                t.column("label", .text)
            }
        }
    }
    
}
