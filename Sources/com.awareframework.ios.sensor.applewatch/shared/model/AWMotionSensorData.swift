//
//  AWMotionSensorData.swift
//  com.awareframework.ios.sensor.applewatch
//
//  Created by Yuuki Nishiyama on 2025/07/07.
//

//
//  AccelerometerEvent.swift
//  CoreAware
//
//  Created by Yuuki Nishiyama on 2018/03/02.
//

import Foundation
import com_awareframework_ios_core
import GRDB

public struct AWMotionSensorData: BaseDbModelSQLite {
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "watchOS"
    public var jsonVersion: Int = 1
    
    public var id: Int64?
    public var timestamp: Int64
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String
    
    public static let databaseTableName = "ios_watch_motion"
    
    public var accX : Double = 0.0
    public var accY : Double = 0.0
    public var accZ : Double = 0.0
    public var roll : Double = 0.0
    public var pitch : Double = 0.0
    public var yaw : Double = 0.0
    public var gravityX : Double = 0.0
    public var gravityY : Double = 0.0
    public var gravityZ : Double = 0.0
    public var rotationX: Double = 0.0
    public var rotationY: Double = 0.0
    public var rotationZ: Double = 0.0
    public var userAccX: Double = 0.0
    public var userAccY: Double = 0.0
    public var userAccZ: Double = 0.0

    public init(timestamp:Int64,
                accX:Double, accY:Double, accZ:Double, 
                roll:Double, pitch:Double,yaw:Double,
                gravityX:Double, gravityY:Double, gravityZ:Double,
                rotationX:Double, rotationY:Double, rotationZ:Double,
                userAccX:Double, userAccY:Double, userAccZ:Double,
                label:String="") {
        self.timestamp = timestamp
        self.accX=accX
        self.accY=accY
        self.accZ=accZ
        self.roll=roll
        self.pitch=pitch
        self.yaw=yaw
        self.gravityX=gravityX
        self.gravityY=gravityY
        self.gravityZ=gravityZ
        self.rotationX=rotationX
        self.rotationY=rotationY
        self.rotationZ=rotationZ
        self.userAccX=userAccX
        self.userAccY=userAccY
        self.userAccZ=userAccZ
        self.label = label
    }
    
    public init(_ dict: Dictionary<String, Any>) {
        self.timestamp = dict["timestamp"] as? Int64 ?? 0
        self.deviceId = dict["deviceId"] as? String ?? ""
        self.label = dict["label"] as? String ?? ""
        self.accX = dict["accX"] as? Double ?? 0
        self.accY = dict["accY"] as? Double ?? 0
        self.accZ = dict["accZ"] as? Double ?? 0
        self.roll = dict["roll"] as? Double ?? 0
        self.pitch = dict["pitch"] as? Double ?? 0
        self.yaw = dict["yaw"] as? Double ?? 0
        self.gravityX = dict["gravityX"] as? Double ?? 0
        self.gravityY = dict["gravityY"] as? Double ?? 0
        self.gravityZ = dict["gravityZ"] as? Double ?? 0
        self.rotationX = dict["rotationX"] as? Double ?? 0
        self.rotationY = dict["rotationY"] as? Double ?? 0
        self.rotationZ = dict["rotationZ"] as? Double ?? 0
        self.userAccX = dict["userAccX"] as? Double ?? 0
        self.userAccY = dict["userAccY"] as? Double ?? 0
        self.userAccZ = dict["userAccZ"] as? Double ?? 0
        
    }
    
    public static func createTable(queue: GRDB.DatabaseQueue ) throws {
        try queue.write { db in
            try db.create(table: AWMotionSensorData.databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("deviceId", .text).notNull()
                t.column("timestamp", .integer).notNull()
                t.column("accX", .double).notNull()
                t.column("accY", .double).notNull()
                t.column("accZ", .double).notNull()
                t.column("roll", .double).notNull()
                t.column("pitch", .double).notNull()
                t.column("yaw", .double).notNull()
                t.column("gravityX", .double).notNull()
                t.column("gravityY", .double).notNull()
                t.column("gravityZ", .double).notNull()
                t.column("rotationX", .double).notNull()
                t.column("rotationY", .double).notNull()
                t.column("rotationZ", .double).notNull()
                t.column("userAccX", .double).notNull()
                t.column("userAccY", .double).notNull()
                t.column("userAccZ", .double).notNull()
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
            "label":label,
            "accX":accX,
            "accY":accY,
            "accZ":accZ,
            "roll":roll,
            "pitch":pitch,
            "yaw":yaw,
            "gravityX":gravityX,
            "gravityY":gravityY,
            "gravityZ":gravityZ,
            "rotationX":rotationX,
            "rotationY":rotationY,
            "rotationZ":rotationZ,
            "userAccX":userAccX,
            "userAccY":userAccY,
            "userAccZ":userAccZ,
        ]
    }
}
