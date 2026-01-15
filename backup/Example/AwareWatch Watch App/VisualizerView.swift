//
//  VisualizerView.swift
//  com.awareframework.ios.sensor.applewatch_Example Watch App
//
//  Created by Yuuki Nishiyama on 2022/12/28.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import SwiftUI
import com_awareframework_ios_sensor_applewatch
import Charts

enum ChartType {
case accelerometer
    case rotation
    case ambientNoise
    case heartrate
    case battery
    case speed
    case heading
    case audioClassification
}

struct VisualizerView: View {

    @State var chartType:ChartType = .accelerometer
    
    var body: some View {
        List{
            NavigationLink("Accelerometer", destination:  ChartView(.accelerometer))
            NavigationLink("Rotation", destination: ChartView(.rotation))
            NavigationLink("Ambient Noist", destination: ChartView(.ambientNoise))
            NavigationLink("Audio Classification", destination: ChartView(.audioClassification))
            NavigationLink("Heart Rate", destination: ChartView(.heartrate))
            NavigationLink("Battery", destination: ChartView(.battery))
            NavigationLink("Speed", destination: ChartView(.speed))
            NavigationLink("Heading", destination: ChartView(.heading))
        }
    }
}

struct VisualizerView_Previews: PreviewProvider {
    static var previews: some View {
        VisualizerView()
    }
}

struct ChartView: View {
    
    var type:ChartType = .accelerometer
    
    init(_ chartType:ChartType) {
        self.type = chartType
    }
    
    @Environment(\.scenePhase) private var scenePhase
    
    @ObservedObject var motionSensor = AWSensor.shared.motionSensor
    @ObservedObject var audioSensor  = AWSensor.shared.audioSensor
    @ObservedObject var hrSensor = AWSensor.shared.hrSensor
    @ObservedObject var batterySensor = AWSensor.shared.batterySensor
    @ObservedObject var locationSensor = AWSensor.shared.locationSensor
    
    var body: some View {
        if scenePhase == .active {
            switch type {
            case .accelerometer:
                VStack {
                    AccelerometerChart(accelerations: motionSensor.accelerations)
                }.navigationTitle("Accelerometer")
            case .rotation:
                VStack {
                    RotationChart(motions: motionSensor.motions)
                }.navigationTitle("Rotation")
            case .ambientNoise:
                VStack {
                    Chart {
                        ForEach(audioSensor.decibels, id: \.date) { item in
                            LineMark(
                                x: .value("Date", item.date),
                                y: .value("Db", item.value)
                            )
                            .foregroundStyle(.brown)
                        }
                    }.padding(3)//.frame(height: 50)
                }.navigationTitle("Ambient Noise")
            case .heartrate:
                VStack {
                    Chart {
                        ForEach(hrSensor.heartrates, id: \.date) { item in
                            LineMark(
                                x: .value("Date", item.date),
                                y: .value("hmp", item.value)
                            )
                            .foregroundStyle(.pink)
                        }
                    }.padding(3)//.frame(height: 50)
                }.navigationTitle("Heatrate")
            case .battery:
                VStack {
                    Chart {
                        ForEach(batterySensor.batteryLevels, id: \.date) { item in
                            LineMark(
                                x: .value("Date", item.date),
                                y: .value("Batter Level", item.value == -1 ? 0 : item.value * 100)
                            )
                            .foregroundStyle(.blue)
                            
                        }
                    }.padding(3).chartYScale(domain: 0...100) // frame(height: 50).
                }.navigationTitle("Battery")
            case .speed:
                VStack {
                    
                    Chart {
                        ForEach(locationSensor.locations, id: \.date) { item in
                            LineMark(x: .value("Date", item.date),
                                     y: .value("Speed", item.value.speed)
                            ).foregroundStyle(.purple)
                        }
                    }.padding(3)//.frame(height: 50)
                }.navigationTitle("Speed")
            case .heading:
                VStack {
                    
                    Chart {
                        ForEach(locationSensor.geomagnetisms, id: \.date) { item in
                            LineMark(x: .value("Date", item.date),
                                     y: .value("Heading", item.value.trueHeading),
                                     series: .value("Company", "True Heading")
                            ).foregroundStyle(.green)
                            LineMark(x: .value("Date", item.date),
                                     y: .value("Heading", item.value.magneticHeading),
                                     series: .value("Company", "Magnetic Heading")
                            ).foregroundStyle(.blue)
                        }
                    }.padding(3).chartYScale(domain: 0...360)//.frame(height: 50)
                }.navigationTitle("Heading")
            case .audioClassification:
                VStack{
                    AudioClassificationChart(audioClasses: audioSensor.audioClasses)
                }.navigationTitle("Audio Classification")
            }
        } else {
            Text("Inactive: Tap to open activate the app")
        }
    }
}

struct AudioClassificationChart: View {
    let audioClasses: [AWAudioClassPoint]
    
    var body: some View {
        if (audioClasses.count != 0) {
            Chart(audioClasses[...5], id: \.family) {
                    BarMark(
                        x: .value("Confidence", $0.confidence),
                        y: .value("Family", $0.family)
                    )
            }.chartXScale(domain: 0...1.0)
                .chartXAxisLabel("Confidence")
//                .chartYAxisLabel("Audio Class")
        }
    }
}


struct AccelerometerChart: View {
    let accelerations: [AWAccelerationLinePoint]

    var body: some View {
        Chart {
            ForEach(accelerations, id: \.date) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("G", item.x),
                    series: .value("Company", "X")
                ).foregroundStyle(.green)
            }
            ForEach(accelerations, id: \.date) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("G", item.y),
                    series: .value("Company", "Y")
                ).foregroundStyle(.blue)
            }
            ForEach(accelerations, id: \.date) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("G", item.z),
                    series: .value("Company", "Z")
                ).foregroundStyle(.red)
            }
        }.padding(3).chartXAxisLabel("Timestamp").chartYAxisLabel("G")
    }
}

struct RotationChart: View {
    let motions: [AWRotationLinePoint]
    
    var body: some View {
        Chart {
            ForEach(motions, id: \.date) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("", item.x),
                    series: .value("Company", "X")
                )
                .foregroundStyle(.green)
            }
            ForEach(motions, id: \.date) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("", item.y),
                    series: .value("Company", "Y")
                )
                .foregroundStyle(.blue)
            }
            ForEach(motions, id: \.date) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("", item.z),
                    series: .value("Company", "Z")
                )
                .foregroundStyle(.red)
            }
        }.padding(3)//.frame(height: 50)
    }
}
