//
//  AWDeviceData.swift
//  com.awareframework.ios.sensor.applewatch
//
//  Created by Yuuki Nishiyama on 2025/07/10.
//


//import Foundation
import com_awareframework_ios_core
import GRDB

#if os(iOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

public struct AWDeviceSensorData: BaseDbModelSQLite {
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "watchOS"
    public var jsonVersion: Int = 1
    
    public var id: Int64?
    public var timestamp: Int64
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String
    
    public static let databaseTableName = "ios_watch_device"
    
    public var pairedIosDeviceId:String = ""
    
    public var name = ""
    public var model = ""
    public var systemName =  ""
    public var systemVersion = ""
    public var preferredContentSizeCategory = ""
    
    public init(timestamp:Int64, pairedIosDeviceId:String, label:String="") {
        self.timestamp = timestamp
        self.pairedIosDeviceId = pairedIosDeviceId
        self.label = label
        
        #if os(iOS)
        #elseif os(watchOS)
        let device = WKInterfaceDevice.current()
        self.name = device.name
        self.model = device.model
        self.systemName =  device.systemName
        self.systemVersion = device.systemVersion
        self.preferredContentSizeCategory = device.preferredContentSizeCategory
        #endif
        
    }
    
    public init(_ dict: Dictionary<String, Any>) {
        self.timestamp = dict["timestamp"] as? Int64 ?? 0
        self.deviceId = dict["deviceId"] as? String
            ?? dict["device_id"] as? String
            ?? AwareUtils.getCommonDeviceId()
        self.pairedIosDeviceId = dict["pairedIosDeviceId"] as? String ?? ""
        self.label = dict["label"] as? String ?? ""
    }
    
    public static func createTable(queue: GRDB.DatabaseQueue ) throws {
        try queue.write { db in
            try db.create(table: AWDeviceSensorData.databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("deviceId", .text).notNull()
                t.column("timestamp", .integer).notNull()
                t.column("pairedIosDeviceId", .text).notNull()
                t.column("name", .text).notNull()
                t.column("model", .text).notNull()
                t.column("systemName", .text).notNull()
                t.column("systemVersion", .text).notNull()
                t.column("preferredContentSizeCategory", .text).notNull()
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
            "pairedIosDeviceId":pairedIosDeviceId,
            "name": name,
            "model": model,
            "systemName": systemName,
            "systemVersion": systemVersion,
            "preferredContentSizeCategory":preferredContentSizeCategory,
            "label":label,
        ]
    }
    
}
