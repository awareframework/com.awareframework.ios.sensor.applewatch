//
//  ContentView.swift
//  Example Watch App
//
//  Created by Yuuki Nishiyama on 2025/07/08.
//

import SwiftUI

import com_awareframework_ios_core
import com_awareframework_ios_sensor_applewatch_watchOS
import WatchConnectivity

struct ContentView: View {
    
    let audio = AWAudioSensor(AWAudioSensor.Config().apply(closure: {config in
        config.debug = true
        config.activateAmbientNoiseSensor = true
        config.activateAudioClassificationSensor = true
        config.storeOnlyTopK = 10
    }));
    
    let battery = AWBatterySensor(AWBatterySensor.Config().apply{ config in
        config.debug = true
        config.intervalSeconds = 1
    })
    
    let location = AWLocationSensor(AWLocationSensor.Config().apply{ config in
        config.debug = true
    })
    
    let motion = AWMotionSensor(AWMotionSensor.Config().apply{config in
        config.debug = true
        config.motionSensorHz = 100
        config.saveIntervalSeconds = 5
    })
    
    let healthKit = AWHealthKitSensor(AWHealthKitSensor.Config().apply {config in
        config.debug = true
    })
    
    let bluetooth = AWBluetoothSensor(AWBluetoothSensor.Config().apply {config in
        config.debug = true
        config.dbHost = "hogehoge.an.r.appspot.com/xx/xx/"
    })
    
    let device = AWDeviceSensor(AWDeviceSensor.Config().apply{config in
        config.debug = true
        config.pairedDeviceIdReceivedHandler = {deviceId in
            print(deviceId)
        }
    })
    
    
    @State private var audioSensorEnabled = false
    
    var body: some View {
        
        VStack {
            Text(AwareUtils.getCommonDeviceId())
            Toggle("Sensor", isOn: $audioSensorEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .blue)).onChange(of: audioSensorEnabled) { oldValue, newValue in
                    if (audioSensorEnabled) {
                        AWSensorManager.shared.set(sensors: [motion]) {
                            AWSensorManager.shared.start {
                                print("start")
                            }
                        }
                    }else{
                        AWSensorManager.shared.stop {
                            print("stop")
                        }
                    }
                }
            Button("Sync") {
                motion.syncConfig?.progressHandler = { progress, error in
                    print("--->", progress)
                }
//                AWSensorManager.shared.sync(force: true, dbHost: "")
            }
            Button("Get Paired Device Info") {
                if AWDeviceSensor.getPairedDeviceId() == nil{
                    device.start()
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
