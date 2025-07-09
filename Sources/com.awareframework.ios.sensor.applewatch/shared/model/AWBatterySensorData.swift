//
//  AWBatterySensorData.swift
//  com.awareframework.ios.sensor.applewatch
//
//  Created by Yuuki Nishiyama on 2025/07/07.
//

import Foundation
import com_awareframework_ios_core
import GRDB

public struct AWBatterySensorData: BaseDbModelSQLite {
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "watchOS"
    public var jsonVersion: Int = 1
    
    public var id: Int64?
    public var timestamp: Int64
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String
    
    public static let databaseTableName = "watch_battery"  // 新しいテーブル名
    
    public var batteryLevel:Double = -1
    public var batteryState:Int = -1
    
//    "timestamp","battery_level","battery_state","label"
    
    public init(timestamp:Int64, batteryLavel:Double, batteryState:Int, label:String="") {
        self.timestamp = timestamp
        self.batteryLevel = batteryLavel
        self.batteryState = batteryState
        self.label = label
    }
    
    public init(_ dict: Dictionary<String, Any>) {
        self.timestamp = dict["timestamp"] as? Int64 ?? 0
        self.deviceId = dict["deviceId"] as? String ?? ""
        self.batteryLevel = dict["batteryLevel"] as? Double ?? -1
        self.batteryState = dict["batteryState"] as? Int ?? -1
        self.label = dict["label"] as? String ?? ""
    }
    
    public static func createTable(queue: GRDB.DatabaseQueue ) throws {
        try queue.write { db in
            try db.create(table: AWBatterySensorData.databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("deviceId", .text).notNull()
                t.column("timestamp", .integer).notNull()
                t.column("batteryLevel", .double).notNull()
                t.column("batteryState", .integer).notNull()
                t.column("os", .text).notNull()
                t.column("timezone", .integer).notNull()
                t.column("jsonVersion", .integer).notNull()
                t.column("label", .text)
            }
        }
    }
    
    public func toDictionary() -> Dictionary<String, Any> {
        return [
            "id": self.id ?? -1,
            "timestamp":timestamp,
            "deviceId":deviceId,
            "batteryLavel":batteryLevel,
            "batteryState":batteryState,
            "label":label,
        ]
    }
    
}

