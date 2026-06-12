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

    public static let databaseTableName = "ios_watch_heading"
    public static let tableName = databaseTableName

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
                z: Double,
                label: String = "") {
        self.timestamp = timestamp
        self.trueHeading = trueHeading
        self.magneticHeading = magneticHeading
        self.headingAccuracy = headingAccuracy
        self.x = x
        self.y = y
        self.z = z
        self.label = label
    }

    public init(_ dict: Dictionary<String, Any>) {
        self.timestamp = dict["timestamp"] as? Int64 ?? 0
        self.deviceId = dict["deviceId"] as? String ?? dict["device_id"] as? String ?? AwareUtils.getCommonDeviceId()
        self.trueHeading = dict["trueHeading"] as? Double ?? dict["true_heading"] as? Double ?? 0.0
        self.magneticHeading = dict["magneticHeading"] as? Double ?? dict["magnetic_heading"] as? Double ?? 0.0
        self.headingAccuracy = dict["headingAccuracy"] as? Double ?? dict["heading_accuracy"] as? Double ?? 0.0
        self.x = dict["x"] as? Double ?? 0.0
        self.y = dict["y"] as? Double ?? 0.0
        self.z = dict["z"] as? Double ?? 0.0
        self.label = dict["label"] as? String ?? ""
    }
    
    
    public static func createTable(queue: GRDB.DatabaseQueue ) throws {
        try queue.write { db in
            let existingColumns = try tableColumns(in: db, tableName: tableName)
            if existingColumns.isEmpty {
                try createCurrentTable(in: db, tableName: tableName)
            } else if needsSchemaMigration(existingColumns) {
                try migrateLegacyTable(in: db, columns: existingColumns)
            }
        }
    }

    private static func tableColumns(in db: Database, tableName: String) throws -> Set<String> {
        let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(\(tableName))")
        return Set(rows.compactMap { $0["name"] as? String })
    }

    private static func needsSchemaMigration(_ columns: Set<String>) -> Bool {
        columns.contains("device_id")
            || columns.contains("true_heading")
            || columns.contains("magnetic_heading")
            || columns.contains("heading_accuracy")
            || !columns.contains("trueHeading")
            || !columns.contains("magneticHeading")
            || !columns.contains("headingAccuracy")
    }

    private static func createCurrentTable(in db: Database, tableName: String) throws {
        try db.create(table: tableName, ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("timestamp", .integer).notNull()
            t.column("deviceId", .text).notNull()
            t.column("label", .text).notNull()
            t.column("timezone", .integer).notNull()
            t.column("os", .text).notNull()
            t.column("jsonVersion", .integer).notNull()
            t.column("trueHeading", .double).notNull()
            t.column("magneticHeading", .double).notNull()
            t.column("headingAccuracy", .double).notNull()
            t.column("x", .double).notNull()
            t.column("y", .double).notNull()
            t.column("z", .double).notNull()
        }
    }

    private static func migrateLegacyTable(in db: Database, columns: Set<String>) throws {
        let temporaryTableName = "\(tableName)_migration"
        try db.execute(sql: "DROP TABLE IF EXISTS \(temporaryTableName)")
        try createCurrentTable(in: db, tableName: temporaryTableName)

        func value(_ preferred: String, legacy: String? = nil, fallback: String) -> String {
            if columns.contains(preferred) { return preferred }
            if let legacy, columns.contains(legacy) { return legacy }
            return fallback
        }

        let deviceId = value("deviceId", legacy: "device_id", fallback: "''")
        let timestamp = value("timestamp", fallback: "0")
        let label = value("label", fallback: "''")
        let timezone = value("timezone", fallback: "\(AwareUtils.getTimeZone())")
        let os = value("os", fallback: "'watchOS'")
        let jsonVersion = value("jsonVersion", fallback: "1")
        let trueHeading = value("trueHeading", legacy: "true_heading", fallback: "0")
        let magneticHeading = value("magneticHeading", legacy: "magnetic_heading", fallback: "0")
        let headingAccuracy = value("headingAccuracy", legacy: "heading_accuracy", fallback: "0")
        let x = value("x", fallback: "0")
        let y = value("y", fallback: "0")
        let z = value("z", fallback: "0")
        let id = columns.contains("id") ? "id" : "NULL"

        try db.execute(sql: """
            INSERT INTO \(temporaryTableName)
                (id, timestamp, deviceId, label, timezone, os, jsonVersion, trueHeading, magneticHeading, headingAccuracy, x, y, z)
            SELECT
                \(id), \(timestamp), \(deviceId), \(label), \(timezone), \(os), \(jsonVersion),
                \(trueHeading), \(magneticHeading), \(headingAccuracy), \(x), \(y), \(z)
            FROM \(tableName)
            """)
        try db.execute(sql: "DROP TABLE \(tableName)")
        try db.execute(sql: "ALTER TABLE \(temporaryTableName) RENAME TO \(tableName)")
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
