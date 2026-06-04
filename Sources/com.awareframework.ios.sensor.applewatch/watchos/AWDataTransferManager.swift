//
//  AWDataTransferManager.swift
//  com.awareframework.ios.sensor.applewatch
//
//  Created by Yuuki Nishiyama on 2026/06/03.
//

import Foundation
import WatchConnectivity
import DataCompression
import com_awareframework_ios_core

// MARK: - State

public enum AWTransferState: Equatable {
    case idle
    case preparing(sensor: String)
    case transferring
    case completed
    case failed(message: String)

    public var displayText: String {
        switch self {
        case .idle:                   return "待機中"
        case .preparing(let name):    return "準備中: \(name)"
        case .transferring:           return "転送中"
        case .completed:              return "完了"
        case .failed(let msg):        return "エラー: \(msg)"
        }
    }

    public var isActive: Bool {
        switch self {
        case .preparing, .transferring: return true
        default: return false
        }
    }
}

// MARK: - Transfer item (one chunk file)

public struct AWTransferItem: Identifiable {
    public let id: UUID
    public let fileName: String
    public var progress: Double
    public var isCompleted: Bool
    public var isCancelled: Bool
    public var isPaused: Bool
}

// MARK: - Manager

public class AWDataTransferManager: NSObject, ObservableObject {

    public static let shared = AWDataTransferManager()

    // Published properties — always updated on main thread
    @Published public var state: AWTransferState = .idle
    @Published public var totalChunks: Int = 0
    @Published public var completedChunks: Int = 0
    @Published public var overallProgress: Double = 0.0
    @Published public var transfers: [AWTransferItem] = []
    @Published public var lastError: String?

    /// Number of sensor records packed into a single compressed chunk.
    public var recordsPerChunk: Int = 500
    public var debug: Bool = false

    /// Convert rows to columnar JSON (keys once, values as arrays) before compression.
    /// Reduces JSON payload size by 3–5× compared to row-oriented format.
    public var useColumnarFormat: Bool = true

    private let workQueue = DispatchQueue(
        label: "com.awareframework.ios.sensor.applewatch.datatransfer",
        qos: .userInitiated
    )
    private var pendingTransfers: [WCSessionFileTransfer] = []
    private var chunkIDs: [Int: UUID] = [:]   // index → stable UUID
    private var pollingTimer: Timer?
    private var completionHandler: ((Error?) -> Void)?
    private var tempFiles: [URL] = []

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Transfer all sensor data from the given sensors to the paired iPhone.
    /// - Parameters:
    ///   - sensors: Sensors whose SQLite data should be exported.
    ///   - completion: Called on the main thread when all transfers finish (or fail).
    public func transferData(sensors: [AwareSensor], completion: ((Error?) -> Void)? = nil) {
        guard !state.isActive else {
            if debug { print("[AWDataTransferManager] Already transferring — skipped.") }
            return
        }
        completionHandler = completion
        resetState()
        workQueue.async { [weak self] in
            self?.prepareAndTransfer(sensors: sensors)
        }
    }

    /// Cancel all in-flight transfers and clean up.
    public func cancel() {
        stopPolling()
        for t in pendingTransfers { t.cancel() }
        pendingTransfers.removeAll()
        chunkIDs.removeAll()
        cleanupTempFiles()
        publish { [weak self] in
            self?.state = .idle
            self?.overallProgress = 0.0
            self?.transfers = []
        }
    }

    // MARK: - Reset

    private func resetState() {
        publish { [weak self] in
            self?.totalChunks = 0
            self?.completedChunks = 0
            self?.overallProgress = 0.0
            self?.transfers = []
            self?.lastError = nil
        }
        pendingTransfers.removeAll()
        chunkIDs.removeAll()
        tempFiles.removeAll()
    }

    // MARK: - Preparation (runs on workQueue)

    private func prepareAndTransfer(sensors: [AwareSensor]) {
        let eligible = sensors.filter { $0.dbEngine != nil }

        guard !eligible.isEmpty else {
            publish { [weak self] in
                self?.state = .completed
                self?.overallProgress = 1.0
                self?.completionHandler?(nil)
            }
            return
        }

        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let sessionTimestamp = Int64(Date().timeIntervalSince1970 * 1000)

        var chunkFiles: [(url: URL, tableName: String, chunkIndex: Int, totalChunks: Int)] = []

        for (sensorIndex, sensor) in eligible.enumerated() {
            guard let engine = sensor.dbEngine else { continue }
            let tableName = engine.config.tableName ?? "sensor_\(sensorIndex)"

            // COUNT first — no data loaded into memory
            let totalCount = engine.count(filter: nil)
            guard totalCount > 0 else {
                if debug { print("[AWDataTransferManager] No records in '\(tableName)'") }
                continue
            }
            let totalBatches = (totalCount + recordsPerChunk - 1) / recordsPerChunk

            publish { [weak self] in
                guard let self else { return }
                self.state = .preparing(sensor: tableName)
                self.overallProgress = Double(sensorIndex) / Double(eligible.count) * 0.3
            }

            // Paginate: fetch recordsPerChunk rows at a time using an ID cursor.
            // Each batch is encoded, compressed, and written to disk before the next
            // batch is fetched — keeping peak memory to one batch at a time.
            var lastId: Int64 = -1
            var batchIndex = 0

            while batchIndex < totalBatches {
                // Variables updated inside the autoreleasepool so GRDB row objects
                // are released promptly after each page is processed.
                var shouldContinue = false
                var newLastId = lastId

                autoreleasepool {
                    let filter = lastId >= 0 ? "id > \(lastId)" : nil
                    guard let rawPage = engine.fetch(filter: filter, limit: recordsPerChunk),
                          !rawPage.isEmpty else {
                        return   // shouldContinue stays false → breaks outer loop
                    }

                    // Advance cursor to the highest id seen in this page
                    newLastId = rawPage.compactMap { row -> Int64? in
                        if let v = row["id"] as? Int64 { return v }
                        if let v = row["id"] as? Int   { return Int64(v) }
                        return nil
                    }.max() ?? (lastId + Int64(rawPage.count))

                    batchIndex += 1
                    let fileName = "aw_\(tableName)_\(sessionTimestamp)_\(batchIndex)of\(totalBatches).json.zlib"
                    let fileURL = docsDir.appendingPathComponent(fileName)

                    do {
                        let safeRows = jsonSafe(rawPage)
                        let payload: Any = useColumnarFormat
                            ? toColumnar(safeRows)
                            : safeRows
                        let jsonData = try JSONSerialization.data(withJSONObject: payload)
                        guard let compressed = jsonData.compress(withAlgorithm: .zlib) else {
                            if debug { print("[AWDataTransferManager] Compression failed: \(fileName)") }
                            shouldContinue = true
                            return
                        }
                        try compressed.write(to: fileURL)
                        tempFiles.append(fileURL)
                        chunkFiles.append((url: fileURL, tableName: tableName,
                                           chunkIndex: batchIndex, totalChunks: totalBatches))
                        shouldContinue = true
                        if debug {
                            let fmt = useColumnarFormat ? "col" : "row"
                            print("[AWDataTransferManager][\(fmt)] \(fileName): \(jsonData.count / 1024) KB → \(compressed.count / 1024) KB")
                        }
                    } catch {
                        publish { [weak self] in self?.lastError = error.localizedDescription }
                        if debug { print("[AWDataTransferManager] Error encoding \(tableName): \(error)") }
                        shouldContinue = true
                    }
                    // safeRows / payload / jsonData / compressed released here when pool drains
                }

                if !shouldContinue { break }
                lastId = newLastId
            }
        }

        if chunkFiles.isEmpty {
            publish { [weak self] in
                self?.state = .completed
                self?.overallProgress = 1.0
                self?.completionHandler?(nil)
            }
            return
        }

        // Hand off file transfers to the main thread (WCSession requirement).
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.totalChunks = chunkFiles.count
            self.state = .transferring

            var items: [AWTransferItem] = []
            for (index, chunk) in chunkFiles.enumerated() {
                let itemID = UUID()
                self.chunkIDs[index] = itemID

                let transfer = WCSession.default.transferFile(chunk.url, metadata: [
                    "type":        "AWDataTransfer",
                    "tableName":   chunk.tableName,
                    "chunkIndex":  chunk.chunkIndex,
                    "totalChunks": chunk.totalChunks,
                    "deviceId":    AwareUtils.getCommonDeviceId(),
                ])
                self.pendingTransfers.append(transfer)

                items.append(AWTransferItem(
                    id: itemID,
                    fileName: chunk.url.lastPathComponent,
                    progress: 0.0,
                    isCompleted: false,
                    isCancelled: false,
                    isPaused: false
                ))
            }

            self.transfers = items
            self.startPolling()
        }
    }

    // MARK: - Progress polling

    private func startPolling() {
        stopPolling()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollProgress()
        }
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func pollProgress() {
        guard !pendingTransfers.isEmpty else {
            stopPolling()
            return
        }

        var totalFraction = 0.0
        var completedCount = 0
        var updatedItems: [AWTransferItem] = []

        for (index, transfer) in pendingTransfers.enumerated() {
            let fraction    = transfer.progress.fractionCompleted
            let isFinished  = transfer.progress.isFinished
            let isCancelled = transfer.progress.isCancelled
            let isPaused    = transfer.progress.isPaused

            totalFraction += fraction
            if isFinished || isCancelled { completedCount += 1 }

            let stableID = chunkIDs[index] ?? UUID()
            updatedItems.append(AWTransferItem(
                id:          stableID,
                fileName:    transfer.file.fileURL.lastPathComponent,
                progress:    fraction,
                isCompleted: isFinished,
                isCancelled: isCancelled,
                isPaused:    isPaused
            ))
        }

        transfers       = updatedItems
        completedChunks = completedCount

        // Transfer phase = 30 %–100 % of overall progress.
        let transferFraction = totalFraction / Double(pendingTransfers.count)
        overallProgress = 0.3 + transferFraction * 0.7

        if completedCount >= pendingTransfers.count {
            stopPolling()
            cleanupTempFiles()
            state           = .completed
            overallProgress = 1.0
            completionHandler?(nil)
        }
    }

    // MARK: - Helpers

    private func cleanupTempFiles() {
        for url in tempFiles {
            try? FileManager.default.removeItem(at: url)
        }
        tempFiles.removeAll()
    }

    private func publish(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    /// Coerces GRDB row values to types that JSONSerialization accepts.
    private func jsonSafe(_ records: [[String: Any]]) -> [[String: Any]] {
        records.map { row in
            row.mapValues { value -> Any in
                switch value {
                case let v as String:  return v
                case let v as Double:  return v
                case let v as Float:   return Double(v)
                case let v as Int:     return v
                case let v as Int64:   return v
                case let v as Int32:   return Int(v)
                case let v as Bool:    return v
                default:               return String(describing: value)
                }
            }
        }
    }

    /// Converts row-oriented `[[String: Any]]` to a columnar `[String: Any]`.
    ///
    /// Fields whose value is identical across every row (e.g. `deviceId`, `os`,
    /// `timezone`) are stored once as a scalar.  Fields that vary per row
    /// (e.g. `timestamp`, `accX`) are stored as arrays.
    ///
    /// Example output:
    /// ```json
    /// {
    ///   "fmt": "col",
    ///   "count": 500,
    ///   "deviceId": "xxx",          ← scalar (same in all rows)
    ///   "os": "watchOS",
    ///   "timestamp": [1234, 1235, ...], ← vector
    ///   "accX":      [0.1,  0.3,  ...]
    /// }
    /// ```
    private func toColumnar(_ rows: [[String: Any]]) -> [String: Any] {
        guard !rows.isEmpty else {
            return ["fmt": "col", "count": 0]
        }

        var result: [String: Any] = ["fmt": "col", "count": rows.count]

        // Gather all keys from the first row; order is arbitrary but consistent.
        let keys = rows[0].keys

        for key in keys {
            let values: [Any] = rows.map { $0[key] ?? NSNull() }

            // Compare as strings to handle mixed numeric types robustly.
            let firstRepr = "\(values[0])"
            let isScalar  = values.allSatisfy { "\($0)" == firstRepr }

            result[key] = isScalar ? values[0] : values
        }

        return result
    }
}

// MARK: - Array + chunked

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map { start in
            let end = Swift.min(start + size, count)
            return Array(self[start..<end])
        }
    }
}
