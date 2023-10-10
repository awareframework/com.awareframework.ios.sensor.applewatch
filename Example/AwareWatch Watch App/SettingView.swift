//
//  SettingView.swift
//  com.awareframework.ios.sensor.applewatch_Example Watch App
//
//  Created by Yuuki Nishiyama on 2023/10/05.
//  Copyright © 2023 CocoaPods. All rights reserved.
//

import SwiftUI

enum SensorType {
    case general
    case accelerometer
    case raw_audio
    case ambient_noise
    case conversation
    case heartrate
    case location
    case bluetooth
    case battery
}

class LocalSensorConfig: ObservableObject {
    @Published var configProrityLocal = true
    @Published var debug = false
    @Published var fileTransfer = true
    
    @Published var accState = false
    @Published var rawAudioState = false
    @Published var ambientNoiseState = false
    @Published var conversationState = false
    @Published var heartrateState = false
    @Published var locationState = false
    @Published var bluetoothState = false
    @Published var batteryState = false
 
    @Published var fileSyncIntervalMin = 5.0
    @Published var accHz = 5.0
    @Published var rawAudioRecordingSec = 300.0
    @Published var rawAudioIntervalSec  = 0.0
}

// Identifiableに準拠していないデータ型の定義
struct SensorName {
    var code = UUID()     // ユニークなIDを自動で設定
    var name : String
    var type : SensorType
}

struct SensorSettingView: View {
    
    @EnvironmentObject private var localConfig:LocalSensorConfig
    
    let sensorNames:[SensorName] = [
         SensorName(name: "General", type: .general),
         SensorName(name: "Accelerometer", type: .accelerometer),
         SensorName(name: "Raw Audio", type: .raw_audio),
         SensorName(name: "Ambient Noise", type: .ambient_noise),
         SensorName(name: "Conversation", type: .conversation),
         SensorName(name: "Heartrate", type: .heartrate),
         SensorName(name: "Location", type: .location),
         SensorName(name: "Bluetooth", type: .bluetooth),
         SensorName(name: "Battery", type: .battery)
    ]
    
    var body: some View {
        List {
            ForEach(sensorNames, id: \.code) { sensorName in
                Group {
                    NavigationLink(sensorName.name) {
                        DetailSettingView(sensorName.type, title: sensorName.name)
                    }.foregroundColor(isSensorActive(sensorName.type) ? .green : .white)
                }
            }
        }
    }
    
    func isSensorActive(_ sensorType:SensorType) -> Bool {
        if sensorType == .accelerometer{
            return localConfig.accState
        }else if sensorType == .raw_audio {
            return localConfig.rawAudioState
        }else if sensorType == .ambient_noise {
            return localConfig.ambientNoiseState
        }else if sensorType == .conversation {
            return localConfig.conversationState
        }else if sensorType == .heartrate {
            return localConfig.heartrateState
        }else if sensorType == .location {
            return localConfig.locationState
        }else if sensorType == .bluetooth {
            return localConfig.bluetoothState
        }else if sensorType == .battery {
            return localConfig.batteryState
        }
        
        return false
    }
}

struct DetailSettingView:View {
    
    @EnvironmentObject var localConfig:LocalSensorConfig;
                    
    let sensorType:SensorType
    let sensorName:String
    
    init(_ sensorType:SensorType, title:String) {
        self.sensorType = sensorType
        self.sensorName = title
    }

    var body: some View {
        List {
            switch self.sensorType {
            case .general:
                Group{
                    Toggle(isOn: $localConfig.configProrityLocal) {
                        Text("Use local settings")
                    }.padding(3)
                    Toggle(isOn: $localConfig.fileTransfer) {
                        Text("Use file transfer")
                    }.padding(3)
                    Toggle(isOn: $localConfig.debug) {
                        Text("Debug mode")
                    }
                }
                Group {
                    VStack {
                        Text("Sync Interval(min): \(Int(localConfig.fileSyncIntervalMin))")
                        Slider(value: $localConfig.fileSyncIntervalMin,
                               in: 0...180,
                               step: 1,
                               minimumValueLabel: Text("0"),
                               maximumValueLabel: Text("180"),
                               label: { EmptyView()}
                        )
                    }
                }
            case .accelerometer:
                Group{
                    VStack {
                        Toggle(isOn: $localConfig.accState) {
                            Text(self.sensorName)
                        }.padding(3)
                        Text("Frequency(Hz): \(Int(localConfig.accHz))")
                        Slider(value: $localConfig.accHz,
                               in: 0...100,
                               step: 1,
                               minimumValueLabel: Text("0"),
                               maximumValueLabel: Text("100"),
                               label: { EmptyView()}
                        )
                    }
                }

            case .ambient_noise:
                Toggle(isOn: $localConfig.ambientNoiseState) {
                    Text(self.sensorName)
                }.padding(3)
            case .raw_audio:
                Group {
                    VStack {
                        Toggle(isOn: $localConfig.rawAudioState) {
                            Text(self.sensorName)
                        }.padding(3)
                        Text("Recording(sec): \(Int(localConfig.rawAudioRecordingSec))")
                        Slider(value: $localConfig.rawAudioRecordingSec,
                               in: 0...600,
                               step: 1,
                               minimumValueLabel: Text("0"),
                               maximumValueLabel: Text("600"),
                               label: { EmptyView()}
                        )
                        Spacer(minLength: 8)
                        Text("Interval(sec): \(Int(localConfig.rawAudioIntervalSec))")
                        Slider(value: $localConfig.rawAudioIntervalSec,
                               in: 0...600,
                               step: 1,
                               minimumValueLabel: Text("0"),
                               maximumValueLabel: Text("600"),
                               label: { EmptyView()}
                        )
                    }
                }
            case .conversation:
                Toggle(isOn: $localConfig.conversationState) {
                    Text(self.sensorName)
                }.padding(3)
            case .heartrate:
                Toggle(isOn: $localConfig.heartrateState) {
                    Text(self.sensorName)
                }.padding(3)
            case .location:
                Toggle(isOn: $localConfig.locationState) {
                    Text(self.sensorName)
                }.padding(3)
            case .bluetooth:
                Toggle(isOn: $localConfig.bluetoothState) {
                    Text(self.sensorName)
                }.padding(3)
            case .battery:
                Toggle(isOn: $localConfig.batteryState) {
                    Text(self.sensorName)
                }.padding(3)
            }

        }.padding(3)
    }
}


struct SettingView_Previews: PreviewProvider {
    static var previews: some View {
        SensorSettingView()
    }
}



//Text("Recording(sec): \(Int(accIntervalHz))")
//Slider(value: $accIntervalHz,
//       in: 0...600,
//       step: 1,
//       minimumValueLabel: Text("0"),
//       maximumValueLabel: Text("600"),
//       label: { EmptyView()}
//).padding(5)
//Spacer(minLength: 5)
//Text("Interval(sec): \(Int(accIntervalHz))")
//Slider(value: $accIntervalHz,
//       in: 0...600,
//       step: 1,
//       minimumValueLabel: Text("0"),
//       maximumValueLabel: Text("600"),
//       label: { EmptyView()}
//).padding(5)


//Text("Frequency(Hz): \(Int(accIntervalHz))")
//Slider(value: $accIntervalHz,
//       in: 0...100,
//       step: 1,
//       minimumValueLabel: Text("0"),
//       maximumValueLabel: Text("100"),
//       label: { EmptyView()}
//).padding(5)
