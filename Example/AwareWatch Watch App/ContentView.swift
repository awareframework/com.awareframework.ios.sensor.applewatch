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
    @State private var motionSensorHz: Double = 50
    
    @State private var untransferredFiles = [URL]()
    
    let awareSensor = AWSensor.shared
    
    @EnvironmentObject private var localConfig:LocalSensorConfig
    
    var body: some View {
        NavigationView {
            List{
                Toggle(isOn: $isRunning) {
                    Text(isRunning ? "Running":"Not Running").foregroundColor(isRunning ? .green : .red)
                }.onChange(of: isRunning) { status in
                    if (status) {
                        awareSensor.requestPermissionNotification { success, error in
                            awareSensor.requestPermissionHealthKit { success, error in
                                
                                AWSensor.shared.start(AWSensorConfig().apply{config in
                                    // sensor configuration
                                    config.motionSensorHz = Int(localConfig.accHz)
                                    config.debug = localConfig.debug
                                    
                                    config.activateMotionSensor = localConfig.accState
                                    config.activateBatterySensor = localConfig.batteryState
                                    config.activateLocationSensor = localConfig.locationState
                                    config.activateRawAudioSensor = localConfig.rawAudioState
                                    config.activateAmbientNoiseSensor = localConfig.ambientNoiseState
                                    config.activateAudioClassificationSensor = localConfig.audioClassificationState
                                    config.activateHeadingSensor = localConfig.locationState
                                    config.activateHRSensor = localConfig.heartrateState
                                    config.activateBluetoothSensor = localConfig.bluetoothState
                                    
//                                    do {
//                                        let classifier = try  VoiceNoiseClassifier()
//                                        config.audioClassifierModel = classifier.model
//                                    } catch  {
//                                        print(error)
//                                    }
//                                    config.audioSensorConfig.storeOnlyFilterData = true
//                                    config.audioSensorConfig.storeOnlyTopK = 10
                                    
                                    config.autoFileTransferInterval = Int(localConfig.fileSyncIntervalMin * 60) // 5 minutes in this case
                                    config.autoFileTransfer = localConfig.fileTransfer  // transfer sensor data during sensing
                                })
                                
                                
                            }}
                    }else{
                        awareSensor.stop()
                    }
                }.padding(3)
//                Divider()
                
                NavigationLink("Settings") {
                    SensorSettingView()
                }
                
                NavigationLink("Visualize") {
                    VisualizerView()
                }
                NavigationLink("Sync Progress") {
                    SyncProgressView()
                }
                
                
                Button("Recovery Sync") {
                    untransferredFiles = awareSensor.getUntransferredFiles()
                    isShowAlert = true
                }.alert("Push to start manual sync with \($untransferredFiles.count) files", isPresented: $isShowAlert,
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
                }).padding(3)

                HStack {
                    Button("Manual Sync") {
                        if let files = getFilesInDir() {
                            for f in files {
                                print(f)
                            }
                        }
                    }.disabled(!WCSession.default.isReachable)
//                    NavigationLink("sync progress") {
//                        SyncProgressView()
//                    }
                }
            }.navigationBarTitleDisplayMode(.automatic)
            .navigationTitle("AWARE")
        }
    }
    
    /**
     ディレクトリ内のディレクトリ・ファイル名リストを取得します。

     - Parameter dirName: ディレクトリ名
     - Returns: ディレクトリ・ファイル名リスト
     */
    func getFilesInDir() -> [String]? {
        if let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            do {
                let items = try FileManager.default.contentsOfDirectory(atPath: documentDirectory)
                return items
            } catch _ {
         
            }
        }
        return nil
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
