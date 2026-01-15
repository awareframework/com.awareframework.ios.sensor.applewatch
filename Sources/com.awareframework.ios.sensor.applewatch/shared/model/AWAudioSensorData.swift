//
//  AWAudioSensorData.swift
//  com.awareframework.ios.sensor.applewatch
//
//  Created by Yuuki Nishiyama on 2025/07/07.
//

import Foundation
import com_awareframework_ios_core
import GRDB

public struct AWAmbientNoiseData: BaseDbModelSQLite {
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "watchOS"
    public var jsonVersion: Int = 1
    
    public var id: Int64?
    public var timestamp: Int64
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String
    
    public static let databaseTableName = "watch_ambient_noise"  // 新しいテーブル名
    
    public var db:Double = 0.0

    // super.init("ambient", header: ["timestamp", "db", "label"])
    
    public init(timestamp:Int64, db:Double, label:String="") {
        self.db = db
        self.timestamp = timestamp
        self.label = label
    }
    
    public init(_ dict: Dictionary<String, Any>) {
        self.timestamp = dict["timestamp"] as? Int64 ?? 0
        self.deviceId = dict["deviceId"] as? String ?? ""
        self.db = dict["db"] as? Double ?? 0
        self.label = dict["label"] as? String ?? ""
    }
    
    public static func createTable(queue: GRDB.DatabaseQueue ) {
        do {
            try queue.write { db in
                try db.create(table: AWAmbientNoiseData.databaseTableName, ifNotExists: true) { t in
                    t.autoIncrementedPrimaryKey("id")
                    t.column("deviceId", .text).notNull()
                    t.column("timestamp", .integer).notNull()
                    t.column("db", .double).notNull()
                    t.column("os", .text).notNull()
                    t.column("timezone", .integer).notNull()
                    t.column("jsonVersion", .integer).notNull()
                    t.column("label", .text).notNull()
                }
            }
        } catch {
            print(error)
        }
    }
    
    public func toDictionary() -> Dictionary<String, Any> {
        return [
            "id": self.id ?? -1,
            "timestamp":timestamp,
            "deviceId":deviceId,
            "db": db,
            "label":label,
        ]
    }
}



public struct AWAudioLabelData: BaseDbModelSQLite {
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "watchOS"
    public var jsonVersion: Int = 1
    
    public var id: Int64?
    public var timestamp: Int64
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String
    
    public static let databaseTableName = "watch_audio_label"  // 新しいテーブル名
    
    public var audioLabel:String = ""
    public var confidence:Double = 0.0

    public init(timestamp:Int64, audioLabel:String, confidence:Double, label:String="") {
        self.timestamp = timestamp
        self.audioLabel = audioLabel
        self.confidence = confidence
        self.label = label
    }
    
    public init(_ dict: Dictionary<String, Any>) {
        self.timestamp  = dict["timestamp"] as? Int64 ?? 0
        self.deviceId   = dict["deviceId"] as? String ?? ""
        self.audioLabel = dict["audioLabel"] as? String ?? ""
        self.confidence = dict["confidence"] as? Double ?? 0
        self.label      = dict["label"] as? String ?? ""
    }
    
    public static func createTable(queue: GRDB.DatabaseQueue ) throws {
        try queue.write { db in
            try db.create(table: AWAudioLabelData.databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("deviceId", .text).notNull()
                t.column("timestamp", .integer).notNull()
                t.column("audioLabel", .text).notNull()
                t.column("confidence", .double).notNull()
                t.column("os", .text).notNull()
                t.column("timezone", .integer).notNull()
                t.column("jsonVersion", .integer).notNull()
                t.column("label", .text).notNull()
            }
        }
    }
    
    public func toDictionary() -> Dictionary<String, Any> {
        return [
            "id": self.id ?? -1,
            "timestamp":timestamp,
            "deviceId":deviceId,
            "audioLabel": audioLabel,
            "confidence": confidence,
            "label":label,
        ]
    }
}
