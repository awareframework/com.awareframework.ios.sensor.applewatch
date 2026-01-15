//
//  ContentView.swift
//  Example
//
//  Created by Yuuki Nishiyama on 2025/07/08.
//

import SwiftUI
import com_awareframework_ios_sensor_applewatch_iOS
import com_awareframework_ios_core

struct ContentView: View {
    let watch = AppleWatchSensor(AppleWatchSensor.Config().apply { config in
        config.debug = true
    })
    
    var body: some View {
        VStack {
//            Image(systemName: "globe")
//                .imageScale(.large)
//                .foregroundStyle(.tint)
            Text("Hello, world!")
            Button(AwareUtils.getCommonDeviceId()) {
                
                
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
