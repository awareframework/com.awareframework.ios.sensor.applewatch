import SwiftUI
import WatchConnectivity
import com_awareframework_ios_sensor_applewatch_watchOS

struct ContentView: View {
    @EnvironmentObject private var controller: WatchSensorController
    @ObservedObject private var transfer: AWDataTransferManager = .shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $controller.isRunning) {
                        Label(
                            controller.isRunning ? "記録中" : "停止中",
                            systemImage: controller.isRunning ? "record.circle.fill" : "pause.circle"
                        )
                    }
                    .tint(.green)
                    .onChange(of: controller.isRunning) { _, newValue in
                        newValue ? controller.start() : controller.stop()
                    }
                }

                Section("センサ") {
                    Toggle("Motion", isOn: $controller.motionEnabled)
                    Toggle("Battery", isOn: $controller.batteryEnabled)
                    Toggle("Device", isOn: $controller.deviceEnabled)
                    Toggle("Heart Rate", isOn: $controller.healthKitEnabled)
                    Toggle("Location", isOn: $controller.locationEnabled)
                    Toggle("Audio", isOn: $controller.audioEnabled)

                    Button {
                        controller.applyiPhoneSettings()
                    } label: {
                        Label("iPhone から設定を取得", systemImage: "iphone.and.arrow.forward")
                    }
                    .disabled(!controller.isPhoneReachable || controller.isRunning)
                }
                .disabled(controller.isRunning)

                Section("同期") {
                    Button {
                        controller.sync()
                    } label: {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(controller.activeSensorCount == 0)

                    HStack {
                        Label(
                            "Phone",
                            systemImage: controller.isPhoneReachable ? "iphone.gen3" : "iphone.slash"
                        )
                        Spacer()
                        Text(controller.isPhoneReachable ? "Reachable" : "Offline")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("iPhone へ転送") {
                    Button {
                        controller.transfer()
                    } label: {
                        HStack {
                            Label("転送開始", systemImage: "arrow.up.to.line.circle.fill")
                            Spacer()
                            AWDataTransferBadge(manager: transfer)
                        }
                    }
                    .disabled(transfer.state.isActive || controller.activeSensorCount == 0)

                    NavigationLink {
                        AWDataTransferProgressView(manager: transfer)
                    } label: {
                        HStack {
                            Label("転送状況", systemImage: "chart.bar.fill")
                            Spacer()
                            Text(transfer.state.displayText)
                                .font(.caption2)
                                .foregroundStyle(stateColor)
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(controller.deviceId)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Text(controller.statusMessage)
                            .font(.caption2)
                            .foregroundStyle(controller.isRunning ? .green : .secondary)
                    }
                }
            }
            .navigationTitle("AWARE")
        }
        .onAppear {
            controller.activate()
        }
    }

    private var stateColor: Color {
        switch transfer.state {
        case .completed: return .green
        case .failed: return .red
        case .idle: return .secondary
        default: return .blue
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchSensorController())
}
