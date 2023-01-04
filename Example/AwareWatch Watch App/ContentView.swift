//
//  ContentView.swift
//  AwareWatch Watch App
//
//  Created by Yuuki Nishiyama on 2022/12/17.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import SwiftUI
import com_awareframework_ios_sensor_applewatch
import WatchConnectivity
import Charts

struct ContentView: View {
    
    @State private var isRunning = false
    @State var isShowAlert = false
    
    @State private var syncInterval: Double = 5
    @State private var motionSensorHz: Double = 100
    
    @State private var untransferredFiles = [URL]()
    
    let awareSensor = AWSensor.shared
    
    var body: some View {
        NavigationView {
            List{
                Toggle(isOn: $isRunning) {
                    Text(isRunning ? "on":"off")
                }.onChange(of: isRunning) { status in
                    if (status) {
                        awareSensor.requestPermissionNotification { success, error in
                            awareSensor.requestPermissionHealthKit { success, error in
                                awareSensor.start(AWSensorConfig().apply{config in
                                    
                                    config.debug = true
                                    
                                    config.motionSensorHz = Int(self.motionSensorHz)
                                    
                                    config.activateHRSensor = true
                                    config.activateAmbientNoiseSensor = true
                                    config.activateMotionSensor = true
                                    config.activateRawAudioSensor = true
                                    config.activateBatterySensor = true
                                    config.activateLocationSensor = true
                                    config.activateHeadingSensor = true
                                    
                                    config.useLocalConfig = true
                                    
                                    config.autoFileTransferInterval = 60  * Int(self.syncInterval)
                                    config.autoFileTransfer = true
                                    config.autoRecoveryFileTransfer = true
                                    
                                }) 
                            }                    }
                    }else{
                        awareSensor.stop()
                    }
                }.padding(3)
                Group {
                    VStack{
                        Text("transfer data files every \(Int(syncInterval)) min")
                        Slider(value: $syncInterval, in: 1...30, step: 1.0).disabled(isRunning).padding(5)
                    }
                }
                Group{
                    NavigationLink("data visualize") {
                        VisualizerView()
                    }
                    Button("recovery file transfer") {
                        untransferredFiles = awareSensor.getUntransferredFiles()
                        isShowAlert = true
                    }
                    .alert("Push to start manual sync with \($untransferredFiles.count) files", isPresented: $isShowAlert,
                           actions: {
                        Button {
                            isShowAlert = false
                        } label: {
                            Text("close")
                        }
                        Button(action: {
                            isShowAlert = false
                            awareSensor.recoveryFileTransfer()
                        }, label: {
                            Text("start")
                        })
                    })
                    .padding(3)
//                    NavigationLink("untransferred files") {
//                        UntransferredFilesView()
//                    }
                    NavigationLink("sync progress") {
                        SyncProgressView()
                    }
                }

            }.padding(2)
        }
       
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
