//
//  AWLocationSensorData.swift
//  com.awareframework.ios.sensor.applewatch
//
//  Created by Yuuki Nishiyama on 2025/07/08.
//

import com_awareframework_ios_core
import GRDB

public struct AWLocationSensorData:BaseDbModelSQLite {
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "watchOS"
    public var jsonVersion: Int = 1
    
    public var id: Int64?
    public var timestamp: Int64
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String

    public static let databaseTableName = "ios_watch_location"
    
    public var latitude: Double = 0
    public var longitude: Double = 0
    public var altitude: Double = 0
    public var ellipsoidalAltitude: Double = 0
    public var horizontalAccuracy: Double = 0
    public var verticalAccuracy: Double = 0
    public var speed: Double = 0
    public var speedAccuracy: Double = 0
    public var course: Double = 0
    public var courseAccuracy: Double = 0
    
    public init(timestamp: Int64,
                latitude: Double,
                longitude: Double,
                altitude: Double,
                ellipsoidalAltitude: Double,
                horizontalAccuracy: Double,
                verticalAccuracy: Double,
                speed: Double,
                speedAccuracy: Double,
                course: Double,
                courseAccuracy: Double,
                label: String) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.ellipsoidalAltitude = ellipsoidalAltitude
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.speed = speed
        self.speedAccuracy = speedAccuracy
        self.course = course
        self.courseAccuracy = courseAccuracy
        self.label = label
    }

    public init(_ dict: Dictionary<String, Any>) {
        self.timestamp = dict["timestamp"] as? Int64 ?? 0
        self.deviceId = dict["device_id"] as? String ?? AwareUtils.getCommonDeviceId()
        self.latitude = dict["latitude"] as? Double ?? 0
        self.longitude = dict["longitude"] as? Double ?? 0
        self.altitude = dict["altitude"] as? Double ?? 0
        self.ellipsoidalAltitude = dict["ellipsoidalAltitude"] as? Double ?? 0
        self.horizontalAccuracy = dict["horizontalAccuracy"] as? Double ?? 0
        self.verticalAccuracy = dict["verticalAccuracy"] as? Double ?? 0
        self.speed = dict["speed"] as? Double ?? 0
        self.speedAccuracy = dict["speedAccuracy"] as? Double ?? 0
        self.course = dict["course"] as? Double ?? 0
        self.courseAccuracy = dict["courseAccuracy"] as? Double ?? 0
        self.label = dict["label"] as? String ?? ""
    }
    
    public func toDictionary() -> Dictionary<String, Any> {
        return [
            "id": id ?? -1,
            "timestamp": timestamp,
            "deviceId": deviceId,
            "latitude": latitude,
            "longitude": longitude,
            "altitude": altitude,
            "ellipsoidalAltitude": ellipsoidalAltitude,
            "horizontalAccuracy": horizontalAccuracy,
            "verticalAccuracy": verticalAccuracy,
            "speed": speed,
            "speedAccuracy": speedAccuracy,
            "course": course,
            "courseAccuracy": courseAccuracy,
            "label": label
        ]
    }
    
    public static func createTable(queue: GRDB.DatabaseQueue) throws {
        try queue.write { db in
            try db.create(table: AWLocationSensorData.databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .integer)
                
                t.column("deviceId", .text)
                t.column("latitude", .double)
                t.column("longitude", .double)
                t.column("altitude", .double)
                t.column("ellipsoidalAltitude", .double)
                t.column("horizontalAccuracy", .double)
                t.column("verticalAccuracy", .double)
                t.column("speed", .double)
                t.column("speedAccuracy", .double)
                t.column("course", .double)
                t.column("courseAccuracy", .double)
                
                t.column("os", .text).notNull()
                t.column("timezone", .integer).notNull()
                t.column("jsonVersion", .integer).notNull()
                t.column("label", .text)
            }
        }
    }
}
