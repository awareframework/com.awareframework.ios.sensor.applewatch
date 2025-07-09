//
//  ContentView.swift
//  Example
//
//  Created by Yuuki Nishiyama on 2025/07/08.
//

import SwiftUI
import com_awareframework_ios_sensor_applewatch_iOS

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            Button("abc") {
                AppleWatchSensor(AppleWatchSensor.Config().apply(closure: { config in
                    config.debug = true
                }))
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
