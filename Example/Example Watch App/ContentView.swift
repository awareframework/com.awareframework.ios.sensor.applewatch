//
//  ContentView.swift
//  Example Watch App
//

import SwiftUI
import com_awareframework_ios_core
import com_awareframework_ios_sensor_applewatch_watchOS
import WatchConnectivity

struct ContentView: View {

    // ── Sensors ──────────────────────────────────────────────────────────────
    let motion = AWMotionSensor(AWMotionSensor.Config().apply { config in
        config.debug = true
        config.motionSensorHz = 100
        config.saveIntervalSeconds = 5
    })

    let battery = AWBatterySensor(AWBatterySensor.Config().apply { config in
        config.debug = true
        config.intervalSeconds = 60
    })

    // ── State ─────────────────────────────────────────────────────────────────
    @State private var sensingEnabled = false
    @State private var motionCount   = 0
    @State private var batteryCount  = 0

    @ObservedObject private var transfer: AWDataTransferManager = .shared

    var body: some View {
        NavigationView {
            List {

                // ── センサー制御 ───────────────────────────────────────────────
                Section("センサー") {
                    Toggle("計測", isOn: $sensingEnabled)
                        .onChange(of: sensingEnabled) { _, newValue in
                            if newValue {
                                AWSensorManager.shared.set(sensors: [motion, battery]) {
                                    AWSensorManager.shared.start { }
                                }
                            } else {
                                AWSensorManager.shared.stop { }
                            }
                            refreshCounts()
                        }

                    HStack {
                        Label("モーション", systemImage: "waveform.path.ecg")
                            .font(.caption)
                        Spacer()
                        Text("\(motionCount) 件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("バッテリー", systemImage: "battery.100")
                            .font(.caption)
                        Spacer()
                        Text("\(batteryCount) 件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // ── データ転送 ─────────────────────────────────────────────────
                Section("転送") {

                    // 転送開始ボタン + バッジ
                    Button {
                        refreshCounts()
                        AWSensorManager.shared.transferAllData { error in
                            if let error {
                                print("[Transfer] エラー: \(error)")
                            }
                        }
                    } label: {
                        HStack {
                            Label("転送開始", systemImage: "arrow.up.to.line.circle.fill")
                            Spacer()
                            AWDataTransferBadge(manager: transfer)
                        }
                    }
                    .disabled(transfer.state.isActive)

                    // 転送詳細画面へのリンク
                    NavigationLink {
                        AWDataTransferProgressView(manager: transfer)
                    } label: {
                        HStack {
                            Label("転送状況", systemImage: "chart.bar.fill")
                            Spacer()
                            Text(transfer.state.displayText)
                                .font(.caption2)
                                .foregroundColor(stateColor)
                        }
                    }
                }

                // ── デバイス情報 ───────────────────────────────────────────────
                Section("デバイス") {
                    Text(AwareUtils.getCommonDeviceId())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .navigationTitle("AWARE Watch")
            .onAppear { refreshCounts() }
        }
    }

    // MARK: - Helpers

    private func refreshCounts() {
        motionCount  = motion.dbEngine?.count(filter: nil) ?? 0
        batteryCount = battery.dbEngine?.count(filter: nil) ?? 0
    }

    private var stateColor: Color {
        switch transfer.state {
        case .completed: return .green
        case .failed:    return .red
        case .idle:      return .secondary
        default:         return .blue
        }
    }
}

#Preview {
    ContentView()
}
