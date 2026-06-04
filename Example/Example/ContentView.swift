//
//  ContentView.swift
//  Example (iPhone)
//

import SwiftUI
import com_awareframework_ios_sensor_applewatch_iOS
import com_awareframework_ios_core

struct ContentView: View {
    @StateObject private var model = WatchDataModel()

    var body: some View {
        NavigationStack {
            List {

                // ── 受信データ ─────────────────────────────────────────────────
                Section {
                    if model.receivedChunks.isEmpty {
                        Label("Watch からのデータ転送を待機中…", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(model.receivedChunks) { chunk in
                            HStack(spacing: 12) {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.accentColor)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(chunk.tableName)
                                        .font(.subheadline).bold()
                                    Text("チャンク \(chunk.chunkIndex) / \(chunk.totalChunks)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(chunk.recordCount) 件")
                                        .font(.caption).bold()
                                    Text(chunk.receivedAt, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: {
                    HStack {
                        Text("受信データ")
                        Spacer()
                        if !model.receivedChunks.isEmpty {
                            Button("クリア") { model.receivedChunks.removeAll() }
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                } footer: {
                    if !model.receivedChunks.isEmpty {
                        Text("合計 \(model.totalRecordCount) 件 (\(model.receivedChunks.count) チャンク)")
                            .font(.caption2)
                    }
                }

                // ── 接続情報 ──────────────────────────────────────────────────
                Section("接続情報") {
                    LabeledContent("iPhone ID", value: AwareUtils.getCommonDeviceId())
                        .font(.caption)
                }
            }
            .navigationTitle("AWARE iPhone")
            .animation(.easeInOut, value: model.receivedChunks.count)
        }
    }
}

// MARK: - Model

private class WatchDataModel: ObservableObject {

    struct ReceivedChunk: Identifiable {
        let id          = UUID()
        let tableName   : String
        let chunkIndex  : Int
        let totalChunks : Int
        let recordCount : Int
        let receivedAt  = Date()
    }

    @Published var receivedChunks: [ReceivedChunk] = []

    var totalRecordCount: Int {
        receivedChunks.reduce(0) { $0 + $1.recordCount }
    }

    private let sensor: AppleWatchSensor

    init() {
        sensor = AppleWatchSensor(AppleWatchSensor.Config().apply { config in
            config.debug = true
        })

        sensor.CONFIG.receivedDataHandler = { [weak self] tableName, chunkIndex, totalChunks, records in
            guard let self else { return }
            self.receivedChunks.append(ReceivedChunk(
                tableName:   tableName,
                chunkIndex:  chunkIndex,
                totalChunks: totalChunks,
                recordCount: records.count
            ))
        }

        sensor.start()
    }
}

#Preview {
    ContentView()
}
