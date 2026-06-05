import SwiftUI
import com_awareframework_ios_core
import com_awareframework_ios_sensor_applewatch_iOS
import com_awareframework_ios_sensor_applewatch_shared

struct ContentView: View {
    @StateObject private var model = WatchDataModel()

    var body: some View {
        NavigationStack {
            List {
                Section("転送状況") {
                    LabeledContent("状態", value: model.transferStateText)
                    LabeledContent("進捗", value: "\(Int(model.transferProgress * 100)) %")
                    ProgressView(value: model.transferProgress)
                    LabeledContent("チャンク", value: "\(model.completedTransferChunks) / \(model.totalTransferChunks)")
                    LabeledContent("受信", value: "\(model.totalReceivedRecordCount) 件")
                    LabeledContent("保存", value: "\(model.totalSavedRecordCount) 件")
                    if !model.currentTransferFileName.isEmpty {
                        LabeledContent("処理中", value: model.currentTransferFileName)
                            .font(.caption)
                    }
                }

                Section {
                    if model.receivedChunks.isEmpty {
                        Label("Watch からのデータ転送を待機中", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.receivedChunks) { chunk in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 12) {
                                    Image(systemName: chunk.saveState.systemImage)
                                        .foregroundStyle(chunk.saveState.color)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(chunk.tableName)
                                            .font(.subheadline.bold())
                                        Text("チャンク \(chunk.chunkIndex) / \(chunk.totalChunks)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(chunk.recordCount) 件")
                                            .font(.caption.bold())
                                        Text(chunk.receivedAt, style: .time)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Text(chunk.saveState.displayText)
                                    .font(.caption2)
                                    .foregroundStyle(chunk.saveState.color)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                } header: {
                    HStack {
                        Text("受信データ")
                        Spacer()
                        if !model.receivedChunks.isEmpty {
                            Button("クリア") { model.clear() }
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                } footer: {
                    Text("Watch から受信した圧縮チャンクを iPhone 側の aware_applewatch SQLite DB に保存します。")
                        .font(.caption2)
                }

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

private final class WatchDataModel: ObservableObject {
    struct ReceivedChunk: Identifiable {
        let id = UUID()
        let tableName: String
        let chunkIndex: Int
        let totalChunks: Int
        let recordCount: Int
        let receivedAt = Date()
        var saveState: SaveState = .saving
    }

    enum SaveState: Equatable {
        case saving
        case saved(Int)
        case skipped(String)
        case failed(String)

        var displayText: String {
            switch self {
            case .saving:
                return "保存中"
            case .saved(let count):
                return "保存済み: \(count) 件"
            case .skipped(let reason):
                return "未保存: \(reason)"
            case .failed(let message):
                return "保存失敗: \(message)"
            }
        }

        var systemImage: String {
            switch self {
            case .saving: return "hourglass"
            case .saved: return "checkmark.circle.fill"
            case .skipped: return "minus.circle"
            case .failed: return "xmark.octagon.fill"
            }
        }

        var color: Color {
            switch self {
            case .saving: return .blue
            case .saved: return .green
            case .skipped: return .secondary
            case .failed: return .red
            }
        }
    }

    @Published var receivedChunks: [ReceivedChunk] = []
    @Published var transferProgress = 0.0
    @Published var transferStateText = "待機中"
    @Published var currentTransferFileName = ""
    @Published var completedTransferChunks = 0
    @Published var totalTransferChunks = 0

    var totalReceivedRecordCount: Int {
        receivedChunks.reduce(0) { $0 + $1.recordCount }
    }

    var totalSavedRecordCount: Int {
        receivedChunks.reduce(0) { total, chunk in
            if case .saved(let count) = chunk.saveState {
                return total + count
            }
            return total
        }
    }

    private let sensor: AppleWatchSensor

    init() {
        let config = AppleWatchSensor.Config().apply { config in
            config.debug = true
            config.dbPath = "aware_applewatch"
            config.dbTableName = AWMotionSensorData.databaseTableName
            config.dbType = .sqlite
        }
        sensor = AppleWatchSensor(config)

        config.receivedDataHandler = { [weak self] tableName, chunkIndex, totalChunks, records in
            self?.handleReceivedData(
                tableName: tableName,
                chunkIndex: chunkIndex,
                totalChunks: totalChunks,
                records: records
            )
        }
        config.fileTransferStatusHandler = { [weak self] tableName, chunkIndex, totalChunks, fileName, state, errorMessage in
            self?.handleFileTransferStatus(
                tableName: tableName,
                chunkIndex: chunkIndex,
                totalChunks: totalChunks,
                fileName: fileName,
                state: state,
                errorMessage: errorMessage
            )
        }

        sensor.start()
    }

    func clear() {
        receivedChunks.removeAll()
        transferProgress = 0.0
        transferStateText = "待機中"
        currentTransferFileName = ""
        completedTransferChunks = 0
        totalTransferChunks = 0
    }

    private func handleFileTransferStatus(
        tableName: String,
        chunkIndex: Int,
        totalChunks: Int,
        fileName: String,
        state: String,
        errorMessage: String?
    ) {
        totalTransferChunks = max(totalTransferChunks, totalChunks)
        currentTransferFileName = fileName

        switch state {
        case "received":
            completedTransferChunks = max(completedTransferChunks, chunkIndex - 1)
            transferProgress = progress(chunkIndex: Double(chunkIndex - 1), totalChunks: totalChunks)
            transferStateText = "受信中: \(tableName)"
        case "processing":
            completedTransferChunks = max(completedTransferChunks, chunkIndex - 1)
            transferProgress = progress(chunkIndex: Double(chunkIndex) - 0.5, totalChunks: totalChunks)
            transferStateText = "処理中: \(tableName)"
        case "decoded":
            completedTransferChunks = max(completedTransferChunks, chunkIndex)
            transferProgress = progress(chunkIndex: Double(chunkIndex), totalChunks: totalChunks)
            transferStateText = completedTransferChunks >= totalTransferChunks
                ? "受信完了"
                : "展開完了: \(tableName)"
        case "saving":
            transferStateText = "保存中: \(tableName)"
            updateSaveState(tableName: tableName, chunkIndex: chunkIndex, state: .saving)
        case "saved":
            transferStateText = "保存完了: \(tableName)"
            updateSavedState(tableName: tableName, chunkIndex: chunkIndex)
        case "save_failed":
            transferStateText = "保存失敗: \(errorMessage ?? fileName)"
            updateSaveState(
                tableName: tableName,
                chunkIndex: chunkIndex,
                state: .failed(errorMessage ?? fileName)
            )
        case "failed":
            transferStateText = "転送処理失敗: \(errorMessage ?? fileName)"
        default:
            transferStateText = state
        }
    }

    private func progress(chunkIndex: Double, totalChunks: Int) -> Double {
        guard totalChunks > 0 else { return 0.0 }
        return min(1.0, max(0.0, chunkIndex / Double(totalChunks)))
    }

    private func handleReceivedData(
        tableName: String,
        chunkIndex: Int,
        totalChunks: Int,
        records: [[String: Any]]
    ) {
        if totalTransferChunks == 0 {
            totalTransferChunks = totalChunks
            completedTransferChunks = max(completedTransferChunks, chunkIndex)
            transferProgress = progress(chunkIndex: Double(chunkIndex), totalChunks: totalChunks)
        }
        transferStateText = "保存中: \(tableName)"

        let chunk = ReceivedChunk(
            tableName: tableName,
            chunkIndex: chunkIndex,
            totalChunks: totalChunks,
            recordCount: records.count
        )

        receivedChunks.insert(chunk, at: 0)
    }

    private func updateSaveState(
        tableName: String,
        chunkIndex: Int,
        state: SaveState
    ) {
        guard let index = receivedChunks.firstIndex(where: {
            $0.tableName == tableName && $0.chunkIndex == chunkIndex
        }) else {
            return
        }
        receivedChunks[index].saveState = state
    }

    private func updateSavedState(tableName: String, chunkIndex: Int) {
        guard let index = receivedChunks.firstIndex(where: {
            $0.tableName == tableName && $0.chunkIndex == chunkIndex
        }) else {
            return
        }
        receivedChunks[index].saveState = .saved(receivedChunks[index].recordCount)
    }
}

#Preview {
    ContentView()
}
