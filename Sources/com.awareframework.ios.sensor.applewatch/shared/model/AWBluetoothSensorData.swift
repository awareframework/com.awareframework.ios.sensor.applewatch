//
//  AWBluetoothSensorData.swift
//  com.awareframework.ios.sensor.applewatch
//
//  Created by Yuuki Nishiyama on 2025/07/07.
//

import com_awareframework_ios_core
import GRDB

public struct AWBluetoothSensorData:BaseDbModelSQLite {

    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "watchOS"
    public var jsonVersion: Int = 1
    
    public var id: Int64?
    public var timestamp: Int64
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String
    
    public static let databaseTableName = "watch_bluetooth"  // 新しいテーブル名
    
    public var identifier:String = ""
    public var name:String = ""
    public var rssi:Double = 0
    
    public init(timestamp:Int64, identifier:String, name:String, rssi:Double, label:String="") {
        self.timestamp = timestamp
        self.identifier = identifier
        self.name = name
        self.label = label
    }
    
    
    public init(_ dict: Dictionary<String, Any>) {
        self.timestamp = dict["timestamp"] as? Int64 ?? 0
        self.identifier = dict["identifier"] as? String ?? ""
        self.name = dict["name"] as? String ?? ""
        self.rssi = dict["rssi"] as? Double ?? 0.0
        self.label = dict["label"] as? String ?? ""
    }
    
    public func toDictionary() -> Dictionary<String, Any> {
        return [
            "id": id ?? -1,
            "timestamp": timestamp,
            "deviceId": deviceId,
            "identifier": identifier,
            "name": name,
            "rssi": rssi,
            "label": label
        ]
    }
    
    public static func createTable(queue: GRDB.DatabaseQueue) throws {
        try queue.write { db in
            try db.create(table: AWBluetoothSensorData.databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .integer).notNull()
                t.column("deviceId", .text).notNull()
                t.column("identifier", .text).notNull()
                t.column("name", .text).notNull()
                t.column("rssi", .double).notNull()
                t.column("os", .text).notNull()
                t.column("timezone", .integer).notNull()
                t.column("jsonVersion", .integer).notNull()
                t.column("label", .text)
            }
        }
    }
}
