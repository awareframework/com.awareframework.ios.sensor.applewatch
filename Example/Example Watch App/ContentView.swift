//
//  ContentView.swift
//  Example Watch App
//
//  Created by Yuuki Nishiyama on 2025/07/08.
//

import SwiftUI

import com_awareframework_ios_sensor_applewatch_watchOS

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
    
    
    @State private var audioSensorEnabled = false
    
    var body: some View {
        
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Toggle("Sensor", isOn: $audioSensorEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .blue)).onChange(of: audioSensorEnabled) { oldValue, newValue in
                    if (audioSensorEnabled) {
                        AWSensorManager.shared.set(sensors: [audio]) {
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
                AWSensorManager.shared.sync(force: true)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
