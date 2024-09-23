//
//  AWBatterySensor.swift
//  com.awareframework.ios.sensor.applewatch-watchOS
//
//  Created by Yuuki Nishiyama on 2022/12/31.
//

import WatchKit
import CoreMotion
import WatchConnectivity
import SwiftUI


public class AWBatterySensor: NSObject, ObservableObject {
    public var sensorData:AWBatterySensorData?

    var timer:Timer? = nil
    var lastBreakTime = Date()
    var isRunning = false
        
    let fileTransferManager = FileTransferManager()
    
    @Published public var batteryLevels = [AWBatteryLinePoint]()
    
    public var config = AWSensorConfig()
    
    func start(_ config:AWSensorConfig){
                
        if (!isRunning) {
            WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
            self.config = config
            isRunning = true
            sensorData = AWBatterySensorData()
            sensorData?.openFileHandler()
            
            startBatterySensors(interval: 60)
        }
    }
    
    func stop(){
        if(isRunning) {
            sensorData?.closeFileHandler()
            isRunning = false
        }
    }

    private func startBatterySensors(interval:Double){
        
        // Configure a timer to fetch the data.
        if self.timer == nil {

            lastBreakTime = Date()
            self.timer = Timer(fire: Date(), interval: TimeInterval(interval), repeats: true, block: { timer in
                let now = Date()
                
                let batteryLevel = Double(WKInterfaceDevice.current().batteryLevel)
                
                //                case unknown = 0
                //                case unplugged = 1 // on battery, discharging
                //                case charging = 2 // charging, less than 100%
                //                case full = 3 // charged, at 100%
                let batteryState = WKInterfaceDevice.current().batteryState
                
                self.batteryLevels.append(AWBatteryLinePoint(date: now, value: batteryLevel))
                if self.batteryLevels.count > 100 {
                    self.batteryLevels.removeFirst()
                }
                
                self.sensorData?.update(batteryLevel: batteryLevel, batteryState: batteryState, label: self.config.label)

                let gap = now.timeIntervalSince(self.lastBreakTime)
                if (gap > Double(self.config.autoFileTransferInterval) && self.config.autoFileTransfer){
                    if let data = self.sensorData {
                        data.closeFileHandler()
                        let originalFileURL = data.filePath
                        self.fileTransferManager.transferFile( fileURL: originalFileURL, debug: self.config.debug)
                    }
                    self.sensorData = AWBatterySensorData()
                    self.sensorData?.openFileHandler()
                    self.lastBreakTime = now
                }
                
            })
                
            // Add the timer to the current run loop.
            RunLoop.current.add(self.timer!, forMode: .default)
        }
    }

    private func stopBatterySensor(){

        if let t = self.timer {
            t.invalidate()
            self.timer = nil
        }
        
        if let data = self.sensorData {
            self.fileTransferManager.transferFile(fileURL: data.filePath, debug: self.config.debug)
        }
    }
    
}

public class AWBatterySensorData: AWSensorData {
    
    init() {
        let header = ["timestamp","battery_level","battery_state","label"]
        super.init("battery", header: header)
    }
    
    func update(batteryLevel:Double,
                batteryState: WKInterfaceDeviceBatteryState,
                label: String){
        
        var values:[String] = []
        
        // set timestamp
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        values.append("\(now)")
        
        values.append(String(batteryLevel))
        values.append(String(batteryState.rawValue))

        // set label
        values.append(label)
        
        self.save(values)
    }
    
}


public struct AWBatteryLinePoint {
    public var date: Date
    public var value: Double
}
