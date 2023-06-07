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
    
    var body: some View {
        NavigationView {
            List{
                Toggle(isOn: $isRunning) {
                    Text(isRunning ? "on":"off")
                }.onChange(of: isRunning) { status in
                    if (status) {
                        awareSensor.requestPermissionNotification { success, error in
                            awareSensor.requestPermissionHealthKit { success, error in
                                
                                AWSensor.shared.start(AWSensorConfig().apply{config in
                                    // sensor configuration
                                    config.motionSensorHz = 100
//                                    config.debug = true
                                    
                                    // list of activated sensors (set `true` need to use)
                                    config.activateMotionSensor = true
                                    
                                    config.activateBatterySensor = true

//                                    config.activateAmbientNoiseSensor = true
//                                    config.activateRawAudioSensor = true
                                    
//                                    config.activateAudioClassificationSensor = true
//                                    do {
//                                        let classifier = try  VoiceNoiseClassifier()
//                                        config.audioClassifierModel = classifier.model
//                                    } catch  {
//                                        print(error)
//                                    }
                                                                        // file transfer settings
                                    config.autoFileTransferInterval = 300 // 5 minutes in this case
                                    config.autoFileTransfer = true  // transfer sensor data during sensing
                                })
                                
                                
                            }}
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
                HStack {
                    Button("全て同期") {
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
            }.padding(2)
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
