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
    case ambientnoise
    case heartrate
    case battery
    case speed
    case heading
    case conversation
}

struct VisualizerView: View {

    @State var chartType:ChartType = .accelerometer
    
    var body: some View {
        List{
            NavigationLink("Accelerometer", destination:  ChartView(.accelerometer))
            NavigationLink("Rotation", destination: ChartView(.rotation))
            NavigationLink("Ambient Noist", destination: ChartView(.ambientnoise))
            NavigationLink("Conversation", destination: ChartView(.conversation))
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
                    Text("Accelerometer")
                    Chart {
                        ForEach(motionSensor.accelerations, id: \.date) { item in
                            LineMark(
                                x: .value("Date", item.date),
                                y: .value("G", item.x),
                                series: .value("Company", "X")
                            ).foregroundStyle(.green)
                        }
                        ForEach(motionSensor.accelerations, id: \.date) { item in
                            LineMark(
                                x: .value("Date", item.date),
                                y: .value("G", item.y),
                                series: .value("Company", "Y")
                            ).foregroundStyle(.blue)
                        }
                        ForEach(motionSensor.accelerations, id: \.date) { item in
                            LineMark(
                                x: .value("Date", item.date),
                                y: .value("G", item.z),
                                series: .value("Company", "Z")
                            ).foregroundStyle(.red)
                        }
                    }.padding(3)//.frame(height: 50)
                }
            case .rotation:
                VStack {
                    Text("Rotation")
                    Chart {
                        ForEach(motionSensor.motions, id: \.date) { item in
                            LineMark(
                                x: .value("Date", item.date),
                                y: .value("", item.x),
                                series: .value("Company", "X")
                            )
                            .foregroundStyle(.green)
                        }
                        ForEach(motionSensor.motions, id: \.date) { item in
                            LineMark(
                                x: .value("Date", item.date),
                                y: .value("", item.y),
                                series: .value("Company", "Y")
                            )
                            .foregroundStyle(.blue)
                        }
                        ForEach(motionSensor.motions, id: \.date) { item in
                            LineMark(
                                x: .value("Date", item.date),
                                y: .value("", item.z),
                                series: .value("Company", "Z")
                            )
                            .foregroundStyle(.red)
                        }
                    }.padding(3)//.frame(height: 50)
                }
                
            case .ambientnoise:
                VStack {
                    Text("Ambient Noise")
                    Chart {
                        ForEach(audioSensor.decibels, id: \.date) { item in
                            LineMark(
                                x: .value("Date", item.date),
                                y: .value("Db", item.value)
                            )
                            .foregroundStyle(.brown)
                        }
                    }.padding(3)//.frame(height: 50)
                }
            case .heartrate:
                VStack {
                    Text("Heat Rate")
                    Chart {
                        ForEach(hrSensor.heartrates, id: \.date) { item in
                            LineMark(
                                x: .value("Date", item.date),
                                y: .value("hmp", item.value)
                            )
                            .foregroundStyle(.pink)
                        }
                    }.padding(3)//.frame(height: 50)
                }
            case .battery:
                VStack {
                    Text("Battery")
                    Chart {
                        ForEach(batterySensor.batteryLevels, id: \.date) { item in
                            LineMark(
                                x: .value("Date", item.date),
                                y: .value("Batter Level", item.value == -1 ? 0 : item.value * 100)
                            )
                            .foregroundStyle(.blue)

                        }
                    }.padding(3).chartYScale(domain: 0...100) // frame(height: 50).
                }
            case .speed:
                VStack {
                    Text("Speed")
                    Chart {
                        ForEach(locationSensor.locations, id: \.date) { item in
                            LineMark(x: .value("Date", item.date),
                                     y: .value("Speed", item.value.speed)
                            ).foregroundStyle(.purple)
                        }
                    }.padding(3)//.frame(height: 50)
                }
            case .heading:
                VStack {
                    Text("Heading")
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
                }
            case .conversation:
                VStack{
                    Text("Conversation")
                    Chart() {
//                        self.audioClasses.sort(by: { $0.family > $1.family })
                        
                        ForEach(audioSensor.audioClasses.sorted(by: { $0.family > $1.family }), id: \.date) {
                            PointMark(
                                x: .value("Date and Time", $0.date),
                                y: .value("Confidence", $0.confidence)
                            ).foregroundStyle(by: .value("Family", $0.family))
                        }
                    }.padding(3).chartXAxisLabel("Date and Time").chartYAxisLabel("Confidence") // .chartYScale(domain: 0...360)//.frame(height: 50)
                }
            }
        } else {
            Text("The application is inactive...")
        }
    }
}




