#if os(iOS)

import Foundation
import WatchConnectivity
import com_awareframework_ios_core
import com_awareframework_ios_sensor_applewatch_shared
import DataCompression

public class AppleWatchSensor: AwareSensor {
    
    public static let TAG = "AWARE::AppleWatch"
    public var CONFIG:AppleWatchSensor.Config = Config()
    public var isWatchCollectingData = false
    public var messageHandler: ((_ message: [String: Any]) -> Void)?
    
    private var syncProgress = WatchSyncProgress()
    private var pairedWatchDeviceId: String?
    private var lastCommunicationMessageAt: Date?
    private var lastFileTransferAt: Date?
    private var lastCommunicationError: String?
    private let fileProcessingQueue = DispatchQueue(
        label: "com.awareframework.ios.sensor.applewatch.file-processing",
        qos: .utility
    )
    private let receivedDataSaveQueue = DispatchQueue(label: "com.awareframework.ios.sensor.applewatch.received-data-save", qos: .utility)
    
    public class Config:SensorConfig{

        public var fileTransferIntervalSeconds:Double = 60 * 15 // 15 minutes

        public var motionSensorHz:Int = 10
        public var watchMotionAccelerometerEnabled: Bool = true
        public var watchMotionDeviceMotionEnabled: Bool = true
        public var sensorObserver:AppleWatchObserver?

        public var keepOriginalFileFromWatch:Bool = false
        public var autoSaveReceivedData:Bool = true

        // Watch sensor enable/disable flags
        public var watchMotionEnabled:Bool    = true
        public var watchBatteryEnabled:Bool   = true
        public var watchDeviceEnabled:Bool    = true
        public var watchHealthKitEnabled:Bool = true
        public var watchLocationEnabled:Bool  = false
        public var watchHeadingEnabled:Bool   = false
        public var watchAudioEnabled:Bool     = false
        public var watchUWBEnabled:Bool       = false
        public var watchBluetoothEnabled:Bool = false
        public var watchBackgroundSessionType: AWBackgroundSessionType = .microphone

        public var watchAudioAmbientNoiseEnabled: Bool = true
        public var watchAudioClassificationEnabled: Bool = true
        public var watchAudioDutyCycleEnabled: Bool = true
        public var watchAudioActiveDuration: TimeInterval = 60
        public var watchAudioRestDuration: TimeInterval = 180

        /// Called whenever a chunk sent by `AWDataTransferManager` (watchOS) is
        /// received and decompressed successfully. The handler may be called off
        /// the main thread.
        ///
        /// - Parameters:
        ///   - tableName:   The SQLite table the records originate from (e.g. `"ios_watch_motion"`).
        ///   - chunkIndex:  1-based index of this chunk within the transfer batch.
        ///   - totalChunks: Total number of chunks in the batch for this table.
        ///   - records:     Decoded JSON rows as `[[String: Any]]`.
        public var receivedDataHandler: ((_ tableName: String,
                                          _ chunkIndex: Int,
                                          _ totalChunks: Int,
                                          _ records: [[String: Any]]) -> Void)?

        /// Called on the main thread as WatchConnectivity transfer files arrive
        /// and are decoded on the iPhone.
        ///
        /// `chunkIndex` and `totalChunks` use the whole transfer session when
        /// watchOS sends `globalChunkIndex/globalTotalChunks` metadata, and fall
        /// back to the per-table chunk numbers otherwise.
        public var fileTransferStatusHandler: ((_ tableName: String,
                                                _ chunkIndex: Int,
                                                _ totalChunks: Int,
                                                _ fileName: String,
                                                _ state: String,
                                                _ errorMessage: String?) -> Void)?

        public override init() {
            super.init()
            dbPath = "aware_apple_watch"
        }
        
        public override func set(config: Dictionary<String, Any>) {
            super.set(config: config)
            if let interval = config["motion_sensor_hz"] as? Int {
                self.motionSensorHz = interval
            }
            if let type = config["watch_background_session_type"] as? String {
                self.watchBackgroundSessionType = AWBackgroundSessionType(rawValueOrDefault: type)
            } else if let type = config["watchBackgroundSessionType"] as? String {
                self.watchBackgroundSessionType = AWBackgroundSessionType(rawValueOrDefault: type)
            }
        }
        
        public func apply(closure:(_ config: AppleWatchSensor.Config) -> Void) -> Self {
            closure(self)
            return self
        }
    }
    
    public init(_ config:AppleWatchSensor.Config) {
        super.init()
        CONFIG = config
        initializeDbEngine(config: config)
        super.syncConfig = DbSyncConfig().apply { syncConfig in
            syncConfig.serverType = config.serverType
            syncConfig.studyNumber = config.studyNumber
            syncConfig.studyKey = config.studyKey
            syncConfig.debug = config.debug
            syncConfig.batchSize = 1000
        }
        initializeReceivedDataTables()
        
        let subscribeNotificationNames = [
                Notification.Name.actionAwareAppleWatchSyncCompletionMotion,
                Notification.Name.actionAwareAppleWatchSyncCompletionNoise,
                Notification.Name.actionAwareAppleWatchSyncCompletionAudioClass,
                Notification.Name.actionAwareAppleWatchSyncCompletionHR,
                Notification.Name.actionAwareAppleWatchSyncCompletionBattery,
                Notification.Name.actionAwareAppleWatchSyncCompletionHeading,
                Notification.Name.actionAwareAppleWatchSyncCompletionLocation,
                Notification.Name.actionAwareAppleWatchSyncCompletionBluetooth,
        ]
        for name in subscribeNotificationNames {
            self.notificationCenter.addObserver(self,
                                                selector: #selector(self.syncProgressEvent),
                                                name: name,
                                                object: nil)
        }
        
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    public override func start(){

    }
    
    public override func stop(){

    }
    
    public override func sync(force: Bool = false) {
        syncProgress = WatchSyncProgress()
        notificationCenter.post(name: .actionAwareAppleWatchSync, object: self)

        guard let syncConfig else {
            notificationCenter.post(
                name: .actionAwareAppleWatchSyncCompletion,
                object: self,
                userInfo: [
                    AppleWatchSensor.EXTRA_STATUS: false,
                    AppleWatchSensor.EXTRA_ERROR: "Sync config is not available",
                ]
            )
            return
        }

        startSequentialSync(
            for: Self.knownWatchTableNames,
            syncConfig: syncConfig,
            currentIndex: 0,
            hasFailure: false,
            lastError: nil
        )
    }

    private func makeSyncConfig(
        from baseConfig: DbSyncConfig,
        tableIndex: Int,
        tableCount: Int,
        completionHandler: DbSyncCompletionHandler?
    ) -> DbSyncConfig {
        let syncConfig = DbSyncConfig()
        syncConfig.removeAfterSync = baseConfig.removeAfterSync
        syncConfig.batchSize = baseConfig.batchSize
        syncConfig.markAsSynced = baseConfig.markAsSynced
        syncConfig.skipSyncedData = baseConfig.skipSyncedData
        syncConfig.keepLastData = baseConfig.keepLastData
        syncConfig.deviceId = baseConfig.deviceId
        syncConfig.debug = baseConfig.debug
        syncConfig.debugLevel = baseConfig.debugLevel
        syncConfig.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.applewatch.sync.queue.\(tableIndex)")
        syncConfig.backgroundSession = baseConfig.backgroundSession
        syncConfig.compactDataFormat = baseConfig.compactDataFormat
        syncConfig.serverType = baseConfig.serverType
        syncConfig.studyNumber = baseConfig.studyNumber
        syncConfig.studyKey = baseConfig.studyKey
        syncConfig.test = baseConfig.test
        syncConfig.progressHandler = { progress, error in
            let tableWeight = 1.0 / Double(max(tableCount, 1))
            let overallProgress = (Double(tableIndex) * tableWeight) + (progress * tableWeight)
            baseConfig.progressHandler?(min(1.0, max(0.0, overallProgress)), error)
        }
        syncConfig.completionHandler = completionHandler
        return syncConfig
    }

    private func makeSyncEngine(for tableName: String) -> Engine {
        Engine.Builder()
            .setPath(CONFIG.dbPath)
            .setType(CONFIG.dbType)
            .setHost(CONFIG.dbHost)
            .setEncryptionKey(CONFIG.dbEncryptionKey)
            .setTableName(tableName)
            .build()
    }

    private func startSequentialSync(
        for tables: [String],
        syncConfig: DbSyncConfig,
        currentIndex: Int,
        hasFailure: Bool,
        lastError: Error?
    ) {
        guard currentIndex < tables.count else {
            var userInfo: [String: Any] = [AppleWatchSensor.EXTRA_STATUS: hasFailure == false]
            if let lastError {
                userInfo[AppleWatchSensor.EXTRA_ERROR] = lastError
            }
            notificationCenter.post(
                name: .actionAwareAppleWatchSyncCompletion,
                object: self,
                userInfo: userInfo
            )
            return
        }

        let tableName = tables[currentIndex]
        let engine = makeSyncEngine(for: tableName)
        let perTableConfig = makeSyncConfig(
            from: syncConfig,
            tableIndex: currentIndex,
            tableCount: tables.count
        ) { [weak self] status, error in
            guard let self else { return }
            self.startSequentialSync(
                for: tables,
                syncConfig: syncConfig,
                currentIndex: currentIndex + 1,
                hasFailure: hasFailure || status == false,
                lastError: error ?? lastError
            )
        }
        engine.startSync(perTableConfig)
    }
    
    private class WatchSyncProgress {
        var motion = 0.0
        var noise  = 0.0
        var audioClass = 0.0
        var location = 0.0
        var hr = 0.0
        var battery = 0.0
        var heading = 0.0
        var bluetooth = 0.0
        
        func isCompleted() -> Bool {
            if (motion == 1 &&
                noise == 1 &&
                audioClass == 1 &&
                location == 1 &&
                hr == 1 &&
                battery == 1 &&
                heading  == 1 &&
                bluetooth == 1) {
                return true
            }
            return false
        }
        
        func progress() -> Double {
            let sensors = [motion, noise, audioClass, location, hr, battery, heading, bluetooth]
            let sensorCount = Double(sensors.count)
            
            var total = 0.0
            for s in sensors {
                total += s
            }
            
            return total/sensorCount
        }
        
        func toString() {
            let sensors = [motion, noise, audioClass, location, hr, battery, heading, bluetooth]
            print(sensors)
        }
    }
    
    @objc func syncProgressEvent(notification: NSNotification) {
        
        var progress = 0.0
        if let userInfo = notification.userInfo as? [String:Any]{
            if let p = userInfo[AppleWatchSensor.EXTRA_STATUS] as? Double {
                if p > 1 {
                    progress = 1
                }else{
                    progress = p
                }
            }
            if let status = userInfo[AppleWatchSensor.EXTRA_STATUS] as? Bool {
                if status {
                    progress = 1
                }else{
                    progress = 0
                }
            }
        }
        
        if (progress > 0) {
            if (notification.name == .actionAwareAppleWatchSyncCompletionMotion) {
                self.syncProgress.motion = progress
            }else if (notification.name == .actionAwareAppleWatchSyncCompletionHR) {
                self.syncProgress.hr = progress
            }else if (notification.name == .actionAwareAppleWatchSyncCompletionNoise) {
                self.syncProgress.noise = progress
            }else if (notification.name == .actionAwareAppleWatchSyncCompletionHeading) {
                self.syncProgress.heading = progress
            }else if (notification.name == .actionAwareAppleWatchSyncCompletionBattery) {
                self.syncProgress.battery = progress
            }else if (notification.name == .actionAwareAppleWatchSyncCompletionLocation) {
                self.syncProgress.location = progress
            }else if (notification.name == .actionAwareAppleWatchSyncCompletionBluetooth) {
                self.syncProgress.bluetooth = progress
            }else if (notification.name == .actionAwareAppleWatchSyncCompletionAudioClass){
                self.syncProgress.audioClass = progress
            }
        }


        if (self.CONFIG.debug) {
            print("Sync Progress: ", self.syncProgress.progress(), notification)
            print(self.syncProgress.toString())
        }
        
        if (self.syncProgress.isCompleted()){
            self.notificationCenter.post(name: .actionAwareAppleWatchSyncCompletion,
                                         object: self,
                                         userInfo: nil)
            self.syncProgress = WatchSyncProgress()
        }else{
            self.notificationCenter.post(name: .actionAwareAppleWatchSyncProgress,
                                         object: self,
                                         userInfo: [AppleWatchSensor.EXTRA_LABEL:self.syncProgress.progress()])
        }
    }
    
    public override func set(label:String){
        self.CONFIG.label = label
        self.notificationCenter.post(name: .actionAwareAppleWatchSetLabel,
                                     object: self,
                                     userInfo: [AppleWatchSensor.EXTRA_LABEL:label])
    }
    
    public func createFileUrl(fileName:String) -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let docsDirect = paths[0]
        let newFileUrl = docsDirect.appendingPathComponent(fileName)
        
        return newFileUrl
    }
    
    private func initializeReceivedDataTables() {
        guard let queue = (dbEngine as? SQLiteEngine)?.getSQLiteInstance() else { return }
        try? AWMotionSensorData.createTable(queue: queue)
        try? AWBatterySensorData.createTable(queue: queue)
        try? AWLocationSensorData.createTable(queue: queue)
        try? AWHeadingSensorData.createTable(queue: queue)
        try? AWBluetoothSensorData.createTable(queue: queue)
        try? AWHeartRateSensorData.createTable(queue: queue)
        try? AWDeviceSensorData.createTable(queue: queue)
        AWAmbientNoiseData.createTable(queue: queue)
        try? AWAudioLabelData.createTable(queue: queue)
    }

    
    public func didReceive(file: WCSessionFile) {
        lastFileTransferAt = Date()

        let fileName = file.fileURL.lastPathComponent
        let newPath  = createFileUrl(fileName: fileName)

        // Remove any stale copy with the same name so copyItem never throws EEXIST.
        try? FileManager.default.removeItem(at: newPath)

        do {
            try FileManager.default.copyItem(at: file.fileURL, to: newPath)
        } catch {
            print("[AWDataTransfer] copyItem failed for \(fileName): \(error)")
            lastCommunicationError = error.localizedDescription
            return
        }

        if CONFIG.debug {
            print("\(#function): \(fileName) received, metadata=\(file.metadata?.description ?? "nil")")
        }

        // AWDataTransferManager files can be identified by metadata or filename.
        let isAWTransfer = (file.metadata?["type"] as? String == "AWDataTransfer")
                        || fileName.hasPrefix("aw_")
        if isAWTransfer {
            notifyFileTransferStatus(
                metadata: file.metadata,
                fileName: fileName,
                state: "received",
                errorMessage: nil
            )
            handleAWDataTransferFile(newPath, metadata: file.metadata)
            return
        }

        // Legacy / other file handling.
        do {
            let data = try Data(contentsOf: newPath)
            if let decompressedData = data.decompress(withAlgorithm: .zlib) {
                if CONFIG.keepOriginalFileFromWatch {
                    var originalFilePath = newPath.lastPathComponent
                    if let theRange = originalFilePath.range(of: ".zlib") {
                        originalFilePath.removeSubrange(theRange)
                        let originalFileUrl = createFileUrl(fileName: originalFilePath)
                        try decompressedData.write(to: originalFileUrl)
                        CONFIG.sensorObserver?.didReceive(file: originalFileUrl)
                    }
                }
            } else if CONFIG.debug {
                print("\(#function): \(fileName) -> decompression returned nil")
            }
        } catch {
            print(error)
            lastCommunicationError = error.localizedDescription
        }
    }

    /// Decompress and decode a zlib-compressed JSON chunk sent by `AWDataTransferManager`.
    /// Handles both row-oriented (`[[String:Any]]`) and columnar (`[String:Any]` with `"fmt":"col"`)
    /// payloads transparently.
    private func handleAWDataTransferFile(_ fileURL: URL, metadata: [String: Any]?) {
        notifyFileTransferStatus(
            metadata: metadata,
            fileName: fileURL.lastPathComponent,
            state: "processing",
            errorMessage: nil
        )

        do {
            let compressed = try Data(contentsOf: fileURL)
            guard let decompressed = compressed.decompress(withAlgorithm: .zlib) else {
                if CONFIG.debug {
                    print("\(#function): decompression failed for \(fileURL.lastPathComponent)")
                }
                notifyFileTransferStatus(
                    metadata: metadata,
                    fileName: fileURL.lastPathComponent,
                    state: "failed",
                    errorMessage: "Decompression failed"
                )
                return
            }

            let json = try JSONSerialization.jsonObject(with: decompressed)

            // Detect columnar payloads and legacy row arrays.
            let records: [[String: Any]]
            if let columnar = json as? [String: Any],
               columnar["fmt"] as? String == "col" {
                records = expandColumnar(columnar)
            } else if let rows = json as? [[String: Any]] {
                records = rows
            } else {
                if CONFIG.debug {
                    print("\(#function): unrecognised JSON shape for \(fileURL.lastPathComponent)")
                }
                notifyFileTransferStatus(
                    metadata: metadata,
                    fileName: fileURL.lastPathComponent,
                    state: "failed",
                    errorMessage: "Unrecognised JSON shape"
                )
                return
            }

            let tableName = tableName(from: metadata, fileName: fileURL.lastPathComponent)

            let chunkIndex  = int(from: metadata?["chunkIndex"])  ?? 1
            let totalChunks = int(from: metadata?["totalChunks"]) ?? 1

            print("[AWDataTransfer] received: table=\(tableName) chunk=\(chunkIndex)/\(totalChunks) rows=\(records.count)")

            CONFIG.receivedDataHandler?(tableName, chunkIndex, totalChunks, records)

            notifyFileTransferStatus(
                metadata: metadata,
                fileName: fileURL.lastPathComponent,
                state: "decoded",
                errorMessage: nil
            )

            if CONFIG.autoSaveReceivedData {
                saveReceivedRecords(
                    records,
                    tableName: tableName,
                    metadata: metadata,
                    fileName: fileURL.lastPathComponent
                )
            }

            if !CONFIG.keepOriginalFileFromWatch {
                try? FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            lastCommunicationError = error.localizedDescription
            notifyFileTransferStatus(
                metadata: metadata,
                fileName: fileURL.lastPathComponent,
                state: "failed",
                errorMessage: error.localizedDescription
            )
            if CONFIG.debug { print("\(#function): \(error)") }
        }
    }

    private func saveReceivedRecords(
        _ records: [[String: Any]],
        tableName: String,
        metadata: [String: Any]?,
        fileName: String
    ) {
        guard !records.isEmpty else {
            notifyFileTransferStatus(
                metadata: metadata,
                fileName: fileName,
                state: "saved",
                errorMessage: nil
            )
            return
        }

        guard let models = watchModels(tableName: tableName, records: records) else {
            notifyFileTransferStatus(
                metadata: metadata,
                fileName: fileName,
                state: "save_failed",
                errorMessage: "Unsupported table: \(tableName)"
            )
            return
        }

        guard let dbEngine else {
            notifyFileTransferStatus(
                metadata: metadata,
                fileName: fileName,
                state: "save_failed",
                errorMessage: "Database engine is not available"
            )
            return
        }

        notifyFileTransferStatus(
            metadata: metadata,
            fileName: fileName,
            state: "saving",
            errorMessage: nil
        )

        receivedDataSaveQueue.async { [weak self] in
            dbEngine.save(models) { error in
                if let error {
                    self?.lastCommunicationError = error.localizedDescription
                    self?.notifyFileTransferStatus(
                        metadata: metadata,
                        fileName: fileName,
                        state: "save_failed",
                        errorMessage: error.localizedDescription
                    )
                } else {
                    self?.notifyFileTransferStatus(
                        metadata: metadata,
                        fileName: fileName,
                        state: "saved",
                        errorMessage: nil
                    )
                }
            }
        }
    }

    private func notifyFileTransferStatus(
        metadata: [String: Any]?,
        fileName: String,
        state: String,
        errorMessage: String?
    ) {
        guard CONFIG.fileTransferStatusHandler != nil else { return }

        let tableName = tableName(from: metadata, fileName: fileName)
        let chunkIndex = int(from: metadata?["globalChunkIndex"])
            ?? int(from: metadata?["chunkIndex"])
            ?? 1
        let totalChunks = int(from: metadata?["globalTotalChunks"])
            ?? int(from: metadata?["totalChunks"])
            ?? 1

        DispatchQueue.main.async { [weak self] in
            self?.CONFIG.fileTransferStatusHandler?(
                tableName,
                chunkIndex,
                totalChunks,
                fileName,
                state,
                errorMessage
            )
        }
    }

    /// Reads an Int from a plist-bridged Any value (accepts Int, Int64, NSNumber).
    private func int(from value: Any?) -> Int? {
        if let v = value as? Int    { return v }
        if let v = value as? Int64  { return Int(v) }
        if let v = value as? NSNumber { return v.intValue }
        return nil
    }

    private func tableName(from metadata: [String: Any]?, fileName: String) -> String {
        if let tableName = metadata?["tableName"] as? String, !tableName.isEmpty {
            return Self.legacyWatchTableNameMap[tableName] ?? tableName
        }

        for tableName in Self.knownWatchTableNames {
            if fileName.hasPrefix("aw_\(tableName)_") || fileName == "\(tableName).zlib" {
                return tableName
            }
        }

        for (legacyTableName, tableName) in Self.legacyWatchTableNameMap {
            if fileName.hasPrefix("aw_\(legacyTableName)_") || fileName == "\(legacyTableName).zlib" {
                return tableName
            }
        }

        let components = fileName.components(separatedBy: "_")
        if components.count >= 3, components[0] == "aw", components[1] == "watch" {
            return Self.legacyWatchTableNameMap["watch_\(components[2])"] ?? "watch_\(components[2])"
        }

        return "unknown"
    }

    private static let knownWatchTableNames = [
        AWMotionSensorData.databaseTableName,
        AWBatterySensorData.databaseTableName,
        AWLocationSensorData.databaseTableName,
        AWHeadingSensorData.databaseTableName,
        AWBluetoothSensorData.databaseTableName,
        AWHeartRateSensorData.databaseTableName,
        AWDeviceSensorData.databaseTableName,
        AWAmbientNoiseData.databaseTableName,
        AWAudioLabelData.databaseTableName,
    ]

    private static let legacyWatchTableNameMap = [
        "watch_motion": AWMotionSensorData.databaseTableName,
        "watch_battery": AWBatterySensorData.databaseTableName,
        "watch_location": AWLocationSensorData.databaseTableName,
        "watch_heading": AWHeadingSensorData.databaseTableName,
        "watch_bluetooth": AWBluetoothSensorData.databaseTableName,
        "watch_heartrate": AWHeartRateSensorData.databaseTableName,
        "watch_device": AWDeviceSensorData.databaseTableName,
        "watch_ambient_noise": AWAmbientNoiseData.databaseTableName,
        "watch_audio_label": AWAudioLabelData.databaseTableName,
    ]

    private func watchModels(
        tableName: String,
        records: [[String: Any]]
    ) -> [any BaseDbModelSQLite]? {
        let normalizedRecords = records.map(normalizedRecord)

        switch tableName {
        case AWMotionSensorData.databaseTableName:
            return normalizedRecords.map { AWMotionSensorData($0) as any BaseDbModelSQLite }
        case AWBatterySensorData.databaseTableName:
            return normalizedRecords.map { AWBatterySensorData($0) as any BaseDbModelSQLite }
        case AWLocationSensorData.databaseTableName:
            return normalizedRecords.map { AWLocationSensorData($0) as any BaseDbModelSQLite }
        case AWHeadingSensorData.databaseTableName:
            return normalizedRecords.map { AWHeadingSensorData($0) as any BaseDbModelSQLite }
        case AWBluetoothSensorData.databaseTableName:
            return normalizedRecords.map { AWBluetoothSensorData($0) as any BaseDbModelSQLite }
        case AWHeartRateSensorData.databaseTableName:
            return normalizedRecords.map { AWHeartRateSensorData($0) as any BaseDbModelSQLite }
        case AWDeviceSensorData.databaseTableName:
            return normalizedRecords.map { AWDeviceSensorData($0) as any BaseDbModelSQLite }
        case AWAmbientNoiseData.databaseTableName:
            return normalizedRecords.map { AWAmbientNoiseData($0) as any BaseDbModelSQLite }
        case AWAudioLabelData.databaseTableName:
            return normalizedRecords.map { AWAudioLabelData($0) as any BaseDbModelSQLite }
        default:
            return nil
        }
    }

    private func normalizedRecord(_ record: [String: Any]) -> [String: Any] {
        record.mapValues { value in
            guard let number = value as? NSNumber else { return value }
            let doubleValue = number.doubleValue
            let int64Value = number.int64Value
            return doubleValue == Double(int64Value) ? int64Value : doubleValue
        }
    }

    /// Expands a columnar payload back to `[[String: Any]]`.
    ///
    /// Scalar fields (non-array values) are broadcast to every row.
    /// Array fields are distributed element-by-element.
    private func expandColumnar(_ dict: [String: Any]) -> [[String: Any]] {
        let count: Int
        if let n = dict["count"] as? Int        { count = n }
        else if let n = dict["count"] as? Int64 { count = Int(n) }
        else { return [] }
        guard count > 0 else { return [] }

        var rows = [[String: Any]](repeating: [:], count: count)

        for (key, value) in dict {
            guard key != "fmt", key != "count" else { continue }

            if let array = value as? [Any] {
                for (i, element) in array.prefix(count).enumerated() {
                    rows[i][key] = element
                }
            } else {
                for i in 0..<count {
                    rows[i][key] = value
                }
            }
        }

        return rows
    }
    
    
    
    public func didReceive(message: [String : Any],
                           replyHandler: @escaping ([String : Any]) -> Void) {
        lastCommunicationMessageAt = Date()
        if let method = message["method"] as? String {
            if (method == "get_settings") {
                var settings: [String: Any] = [
                    "motion_sensor_hz": self.CONFIG.motionSensorHz,
                    "file_transfer_interval_seconds": self.CONFIG.fileTransferIntervalSeconds,
                    "label": self.CONFIG.label,
                    "debug": self.CONFIG.debug,
                    "watch_motion_accelerometer_enabled": self.CONFIG.watchMotionAccelerometerEnabled,
                    "watch_motion_device_motion_enabled": self.CONFIG.watchMotionDeviceMotionEnabled,
                    "watch_motion_enabled":    self.CONFIG.watchMotionEnabled,
                    "watch_battery_enabled":   self.CONFIG.watchBatteryEnabled,
                    "watch_device_enabled":    self.CONFIG.watchDeviceEnabled,
                    "watch_healthkit_enabled": self.CONFIG.watchHealthKitEnabled,
                    "watch_location_enabled":  self.CONFIG.watchLocationEnabled,
                    "watch_heading_enabled":   self.CONFIG.watchHeadingEnabled,
                    "watch_audio_enabled":     self.CONFIG.watchAudioEnabled,
                    "watch_uwb_enabled":       self.CONFIG.watchUWBEnabled,
                    "watch_bluetooth_enabled": self.CONFIG.watchBluetoothEnabled,
                    "watch_background_session_type": self.CONFIG.watchBackgroundSessionType.rawValue,
                    "watch_audio_ambient_noise_enabled": self.CONFIG.watchAudioAmbientNoiseEnabled,
                    "watch_audio_classification_enabled": self.CONFIG.watchAudioClassificationEnabled,
                    "watch_audio_duty_cycle_enabled": self.CONFIG.watchAudioDutyCycleEnabled,
                    "watch_audio_active_duration": self.CONFIG.watchAudioActiveDuration,
                    "watch_audio_rest_duration": self.CONFIG.watchAudioRestDuration,
                ]
                if let host = self.CONFIG.dbHost {
                    settings["db_host"] = host
                }
                replyHandler(settings)
            }else if (method == "get_device_id") {
                replyHandler(
                    ["device_id":AwareUtils.getCommonDeviceId()]
                )
            }else if (method == "manual_device_id_exchange") {
                pairedWatchDeviceId = message["device_id"] as? String
                replyHandler(
                    ["device_id": AwareUtils.getCommonDeviceId(),
                     "paired_device_id": pairedWatchDeviceId ?? ""]
                )
            }else {
                replyHandler(["status": "unsupported"])
            }
        } else {
            replyHandler(["status": "ignored"])
        }
    }
    
    public func communicationDebugStatus() -> AWCommunicationDebugStatus {
        guard WCSession.isSupported() else {
            return AWCommunicationDebugStatus(
                isSupported: false,
                activationState: "unsupported",
                isReachable: false,
                hasContentPending: false,
                outstandingFileTransferCount: 0,
                outstandingUserInfoTransferCount: 0,
                localDeviceId: AwareUtils.getCommonDeviceId(),
                pairedDeviceId: pairedWatchDeviceId,
                lastMessageAt: lastCommunicationMessageAt,
                lastFileTransferAt: lastFileTransferAt,
                lastError: lastCommunicationError
            )
        }
        
        let session = WCSession.default
        return AWCommunicationDebugStatus(
            isSupported: true,
            activationState: session.activationState.debugDescription,
            isReachable: session.isReachable,
            hasContentPending: session.hasContentPending,
            outstandingFileTransferCount: session.outstandingFileTransfers.count,
            outstandingUserInfoTransferCount: session.outstandingUserInfoTransfers.count,
            localDeviceId: AwareUtils.getCommonDeviceId(),
            pairedDeviceId: pairedWatchDeviceId,
            lastMessageAt: lastCommunicationMessageAt,
            lastFileTransferAt: lastFileTransferAt,
            lastError: lastCommunicationError
        )
    }
    
    public func requestManualDeviceIdExchange(_ handler: @escaping (Result<String, Error>) -> Void) {
        guard WCSession.isSupported() else {
            handler(.failure(AppleWatchCommunicationError.unsupported))
            return
        }
        
        let message = [
            "method": "manual_device_id_exchange",
            "device_id": AwareUtils.getCommonDeviceId(),
        ]
        WCSession.default.sendMessage(message) { [weak self] response in
            self?.lastCommunicationMessageAt = Date()
            let watchDeviceId = response["device_id"] as? String ?? ""
            self?.pairedWatchDeviceId = watchDeviceId.isEmpty ? nil : watchDeviceId
            handler(.success(watchDeviceId))
        } errorHandler: { [weak self] error in
            self?.lastCommunicationError = error.localizedDescription
            handler(.failure(error))
        }
    }
        
}

private enum AppleWatchCommunicationError: LocalizedError {
    case unsupported
    
    var errorDescription: String? {
        "WatchConnectivity is not supported on this device."
    }
}

private extension WCSessionActivationState {
    var debugDescription: String {
        switch self {
        case .notActivated:
            return "notActivated"
        case .inactive:
            return "inactive"
        case .activated:
            return "activated"
        @unknown default:
            return "unknown"
        }
    }
}

extension AppleWatchSensor {
    
//    private func saveLocationData(data decompressedData:Data, path:URL){
////        "timestamp",
////        "latitude",
////        "longitude",
////        "altitude",
////        "ellipsoidal_altitude",
////        "horizontal_accuracy",
////        "vertical_accuracy",
////        "speed",
////        "speed_accuracy",
////        "course",
////        "course_accuracy",
////        "label"
//        
//        let decompressedDataStr = String(data: decompressedData, encoding: .utf8)
//        let csvLines = decompressedDataStr!.components(separatedBy: .newlines)
//        var buffer:[AppleWatchLocationData] = []
//
//        var isHeader = true
//
//        for line in csvLines {
//            if (isHeader) {
//                isHeader = false
//                continue
//            }
//
//            let elements = line.components(separatedBy: ",")
//            if (elements.count < 12) {
//                continue
//            }
//
//            let watchLocationData = AppleWatchLocationData()
//            let timestamp = Int64(Double(elements[0]) ?? 0)
//            watchLocationData.timestamp = timestamp
//            watchLocationData.latitude = Double(elements[1]) ?? 0
//            watchLocationData.longitude = Double(elements[2]) ?? 0
//            watchLocationData.altitude = Double(elements[3]) ?? 0
//            watchLocationData.ellipsoidal_altitude = Double(elements[4]) ?? 0
//            watchLocationData.horizontal_accuracy = Double(elements[5]) ?? 0
//            watchLocationData.vertical_accuracy = Double(elements[6]) ?? 0
//            watchLocationData.speed = Double(elements[7]) ?? 0
//            watchLocationData.speed_accuracy = Double(elements[8]) ?? 0
//            watchLocationData.course = Double(elements[9]) ?? 0
//            watchLocationData.course_accuracy = Double(elements[10]) ?? 0
//            watchLocationData.label = CONFIG.label
//            // self.CONFIG.sensorObserver?.onBatteryChanged(data: watchBatteryData.toDictionary())
//
//            buffer.append(watchLocationData)
//
//            if buffer.count > 100 {
//                dbEngine?.save(buffer)
//                buffer.removeAll()
//            }
//        }
//        dbEngine?.save(buffer)
//        do {
//            try FileManager.default.removeItem(at: path)
//        } catch {
//            print(error)
//        }
//    }
//
//    private func saveHeadingData(data decompressedData:Data, path:URL){
//
//        let decompressedDataStr = String(data: decompressedData, encoding: .utf8)
//        let csvLines = decompressedDataStr!.components(separatedBy: .newlines)
//        var buffer:[AppleWatchHeadingData] = []
//
//        var isHeader = true
//
//        for line in csvLines {
//            if (isHeader) {
//                isHeader = false
//                continue
//            }
//
//            let elements = line.components(separatedBy: ",")
//            if (elements.count < 8) {
//                continue
//            }
//
//            let watchHeadingData = AppleWatchHeadingData()
//            let timestamp = Int64(Double(elements[0]) ?? 0)
//            watchHeadingData.timestamp = timestamp
//            watchHeadingData.true_heading = Double(elements[1]) ?? 0
//            watchHeadingData.magnetic_heading = Double(elements[2]) ?? 0
//            watchHeadingData.heading_accuracy = Double(elements[3]) ?? 0
//            watchHeadingData.x = Double(elements[4]) ?? 0
//            watchHeadingData.y = Double(elements[5]) ?? 0
//            watchHeadingData.z = Double(elements[6]) ?? 0
//            watchHeadingData.label = CONFIG.label
//            // self.CONFIG.sensorObserver?.onBatteryChanged(data: watchBatteryData.toDictionary())
//
//            buffer.append(watchHeadingData)
//
//            if buffer.count > 100 {
//                dbEngine?.save(buffer)
//                buffer.removeAll()
//            }
//        }
//        dbEngine?.save(buffer)
//        do {
//            try FileManager.default.removeItem(at: path)
//        } catch {
//            print(error)
//        }
//    }
//    
//    private func saveBatteryData(data decompressedData:Data, path:URL){
//        let decompressedDataStr = String(data: decompressedData, encoding: .utf8)
//        let csvLines = decompressedDataStr!.components(separatedBy: .newlines)
//        var buffer:[AppleWatchBatteryData] = []
//        
//        var isHeader = true
//        
//        for line in csvLines {
//            if (isHeader) {
//                isHeader = false
//                continue
//            }
//            
//            let elements = line.components(separatedBy: ",")
//            if (elements.count < 3) {
//                continue
//            }
//            
//            let watchBatteryData = AppleWatchBatteryData()
//            let timestamp = Int64(Double(elements[0]) ?? 0)
//            watchBatteryData.timestamp = timestamp
//            watchBatteryData.battery_level = Double(elements[1]) ?? 0
//            watchBatteryData.battery_state = Int(elements[2]) ?? 0
//            watchBatteryData.label = CONFIG.label
//            // self.CONFIG.sensorObserver?.onBatteryChanged(data: watchBatteryData.toDictionary())
//            
//            buffer.append(watchBatteryData)
//
//        }
//        dbEngine?.save(buffer)
//        do {
//            try FileManager.default.removeItem(at: path)
//        } catch {
//            print(error)
//        }
//    }
//    
//    private func saveAmbientNoiseData(data decompressedData:Data, path:URL){
//        let decompressedDataStr = String(data: decompressedData, encoding: .utf8)
//        let csvLines = decompressedDataStr!.components(separatedBy: .newlines)
//        var buffer:[AppleWatchAudioData] = []
//        
//        var isHeader = true
//        
//        for line in csvLines {
//            if (isHeader) {
//                isHeader = false
//                continue
//            }
//            
//            let elements = line.components(separatedBy: ",")
//            if (elements.count < 2) {
//                continue
//            }
//            
//            let watchAudioData = AppleWatchAudioData()
//            let timestamp = Int64(Double(elements[0]) ?? 0)
//            watchAudioData.timestamp = timestamp
//            watchAudioData.decibel = Double(elements[1]) ?? 0
//            watchAudioData.label = CONFIG.label
//            self.CONFIG.sensorObserver?.onAudioChanged(data: watchAudioData.toDictionary())
//            
//            buffer.append(watchAudioData)
//            if buffer.count > 100 {
//                dbEngine?.save(buffer)
//                buffer.removeAll()
//            }
//        }
//        dbEngine?.save(buffer)
//        do {
//            try FileManager.default.removeItem(at: path)
//        } catch {
//            print(error)
//        }
//    }
//    
//    private func saveMotionData(data decompressedData:Data, path:URL) {
//        let decompressedDataStr = String(data: decompressedData, encoding: .utf8)
//        let csvLines = decompressedDataStr!.components(separatedBy: .newlines)
//        var buffer:[AppleWatchMotionData] = []
//        var isHeader = true
//        
//        for line in csvLines {
//            if (isHeader) {
//                isHeader = false
//                continue
//            }
//
//            let elements = line.components(separatedBy: ",")
//            if (elements.count < 15) {
//                continue
//            }
//
//            let watchData = AppleWatchMotionData()
//            watchData.timestamp = Int64(Double(elements[0]) ?? 0)
//            watchData.acc_x = Double(elements[1]) ?? 0
//            watchData.acc_y = Double(elements[2]) ?? 0
//            watchData.acc_z = Double(elements[3]) ?? 0
//            watchData.roll = Double(elements[4]) ?? 0
//            watchData.pitch = Double(elements[5]) ?? 0
//            watchData.yaw = Double(elements[6]) ?? 0
//            watchData.gravity_x = Double(elements[7]) ?? 0
//            watchData.gravity_y = Double(elements[8]) ?? 0
//            watchData.gravity_z = Double(elements[9]) ?? 0
//            watchData.rotation_x = Double(elements[10]) ?? 0
//            watchData.rotation_y = Double(elements[11]) ?? 0
//            watchData.rotation_z = Double(elements[12]) ?? 0
//            watchData.user_acc_x = Double(elements[13]) ?? 0
//            watchData.user_acc_y = Double(elements[14]) ?? 0
//            watchData.user_acc_z = Double(elements[15]) ?? 0
//            watchData.label = CONFIG.label
//            
//            self.CONFIG.sensorObserver?.onMotionChanged(data: watchData.toDictionary())
//            
//            buffer.append(watchData)
//            if buffer.count > 10000 {
//                dbEngine?.save(buffer)
//                buffer.removeAll()
//            }
//        }
//        
//        dbEngine?.save(buffer)
//        
//        do {
//            try FileManager.default.removeItem(at: path)
//        }catch {
//            print(error)
//        }
//    }
//    
//    private func saveHealthKitData(data decompressedData:Data, path:URL) {
//        let decompressedDataStr = String(data: decompressedData, encoding: .utf8)
//        let csvLines = decompressedDataStr!.components(separatedBy: .newlines)
//        var buffer:[AppleWatchHeartRateData] = []
//        var isHeader = true
//        for line in csvLines {
//            if (isHeader) {
//                isHeader = false
//                continue
//            }
//
//            let elements = line.components(separatedBy: ",")
//            if (elements.count < 2) {
//                continue
//            }
//
//            let watchData = AppleWatchHeartRateData()
//            watchData.timestamp = Int64(Double(elements[0]) ?? 0)
//            watchData.hr = Double(elements[1]) ?? 0
//            watchData.label = CONFIG.label
//            self.CONFIG.sensorObserver?.onHeartRateChanged(data: watchData.toDictionary())
//            
//            buffer.append(watchData)
//            if buffer.count > 100 {
//                dbEngine?.save(buffer)
//                buffer.removeAll()
//            }
//        }
//        
//        dbEngine?.save(buffer)
//        do {
//            try FileManager.default.removeItem(at: path)
//        }catch {
//            print(error)
//        }
//    }
//    
//    private func saveRawAudioData(data decompressedData:Data,path:URL) {
//        let watchAudioFileData = AppleWatchAudioFileData()
//        watchAudioFileData.timestamp = Int64(Date().timeIntervalSince1970 * 1000.0)
//        watchAudioFileData.file_name = path.lastPathComponent;
//        dbEngine?.save(watchAudioFileData)
//        
//        let rawAudioFile = createFileUrl(fileName: path.lastPathComponent.split(separator: ".")[0]+".m4a")
//        do {
//            try decompressedData.write(to: rawAudioFile)
//        }catch{
//            print(error)
//        }
//        
//        self.CONFIG.sensorObserver?.onAudioFileReceived(data: rawAudioFile)
//        
//        do {
//            try FileManager.default.removeItem(at: path)
//        }catch{
//            print(error)
//        }
//    }
//    
//    
//    private func saveAudioClassifierData(data decompressedData: Data, path:URL){
//        let decompressedDataStr = String(data: decompressedData, encoding: .utf8)
//        let csvLines = decompressedDataStr!.components(separatedBy: .newlines)
//        var buffer:[AppleWatchAudioClassifierData] = []
//        
//        var isHeader = true
//        
//        for line in csvLines {
//            if (isHeader) {
//                isHeader = false
//                continue
//            }
//            
//            let elements = line.components(separatedBy: ",")
//            if (elements.count < 2) {
//                continue
//            }
//            
//            let watchAudioClassData = AppleWatchAudioClassifierData()
//            let timestamp = Int64(Double(elements[0]) ?? 0)
//            watchAudioClassData.timestamp = timestamp
//            watchAudioClassData.confidence = Double(elements[2]) ?? 0
//            watchAudioClassData.identifier = String(elements[1])
//            watchAudioClassData.label = CONFIG.label
////            self.CONFIG.sensorObserver?.onAudioChanged(data: watchAudioData.toDictionary())
//            
//            buffer.append(watchAudioClassData)
//            if buffer.count > 100 {
//                dbEngine?.save(buffer)
//                buffer.removeAll()
//            }
//        }
//        dbEngine?.save(buffer)
//        do {
//            try FileManager.default.removeItem(at: path)
//        } catch {
//            print(error)
//        }
//    }
//    
//    
//    
//    private func saveBluetoothData(data decompressedData: Data, path:URL){
//        let decompressedDataStr = String(data: decompressedData, encoding: .utf8)
//        let csvLines = decompressedDataStr!.components(separatedBy: .newlines)
//        var buffer:[AppleWatchBluetoothData] = []
//        
//        var isHeader = true
//        
//        for line in csvLines {
//            if (isHeader) {
//                isHeader = false
//                continue
//            }
//            
//            let elements = line.components(separatedBy: ",")
//            if (elements.count < 2) {
//                continue
//            }
//            
//            let data = AppleWatchBluetoothData()
//            let timestamp = Int64(Double(elements[0]) ?? 0)
//            data.timestamp = timestamp
//            data.identifier = String(elements[1])
//            data.name = String(elements[2])
//            data.rssi = Double(elements[3]) ?? 0
//            data.label = CONFIG.label
//                        
//            buffer.append(data)
//            if buffer.count > 100 {
//                dbEngine?.save(buffer)
//                buffer.removeAll()
//            }
//        }
//        dbEngine?.save(buffer)
//        do {
//            try FileManager.default.removeItem(at: path)
//        } catch {
//            print(error)
//        }
//    }
}

public protocol AppleWatchObserver {
    func onMotionChanged(data:Dictionary<String, Any>)
    func onAudioChanged(data:Dictionary<String, Any>)
    func onAudioFileReceived(data:URL)
    func onHeartRateChanged(data:Dictionary<String, Any>)
    func didReceive(file: URL)
}


extension Notification.Name{
    public static let actionAwareAppleWatch         = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH)
    public static let actionAwareAppleWatchStart    = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_START)
    public static let actionAwareAppleWatchStop     = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_STOP)
    public static let actionAwareAppleWatchSync     = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SYNC)
    public static let actionAwareAppleWatchSetLabel = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SET_LABEL)
    public static let actionAwareAppleWatchSyncCompletion = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SYNC_COMPLETION)
    public static let actionAwareAppleWatchSyncProgress = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SYNC_PROGRESS)
    
    public static let actionAwareAppleWatchRunning = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_RUNNING)
    
    
    public static let actionAwareAppleWatchSyncMotion     = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SYNC_MOTION)
    public static let actionAwareAppleWatchSyncNoise      = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SYNC_NOISE)
    public static let actionAwareAppleWatchSyncAudioClass = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SYNC_AUDIOCLASS)
    public static let actionAwareAppleWatchSyncBluetooth  = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SYNC_BLUETOOTH)
    public static let actionAwareAppleWatchSyncHR         = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SYNC_HR)
    public static let actionAwareAppleWatchSyncLocation   = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SYNC_LOCATION)
    public static let actionAwareAppleWatchSyncBattery    = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SYNC_BATTERY)
    public static let actionAwareAppleWatchSyncHeading    = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SYNC_HEADING)
    
    public static let actionAwareAppleWatchSyncCompletionMotion = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SYNC_COMPLETION_MOTION)
    public static let actionAwareAppleWatchSyncCompletionNoise = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SYNC_COMPLETION_NOISE)
    public static let actionAwareAppleWatchSyncCompletionAudioClass = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SYNC_COMPLETION_AUDIOCLASS)
    public static let actionAwareAppleWatchSyncCompletionBluetooth = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SYNC_COMPLETION_BLUETOOTH)
    public static let actionAwareAppleWatchSyncCompletionHR = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SYNC_COMPLETION_HR)
    public static let actionAwareAppleWatchSyncCompletionLocation = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SYNC_COMPLETION_LOCATION)
    public static let actionAwareAppleWatchSyncCompletionBattery = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SYNC_COMPLETION_BATTERY)
    public static let actionAwareAppleWatchSyncCompletionHeading = Notification.Name(AppleWatchSensor.ACTION_AWARE_APPLEWATCH_SYNC_COMPLETION_HEADING)
}

extension AppleWatchSensor{
    public static let ACTION_AWARE_APPLEWATCH       = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH"
    public static let ACTION_AWARE_APPLEWATCH_START = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_START"
    public static let ACTION_AWARE_APPLEWATCH_STOP  = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_STOP"
    public static let ACTION_AWARE_APPLEWATCH_SET_LABEL = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SET_LABEL"
    public static let ACTION_AWARE_APPLEWATCH_SYNC  = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SENSOR_SYNC"
    public static let ACTION_AWARE_APPLEWATCH_SYNC_COMPLETION = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SYNC_SUCCESS_COMPLETION"
    public static let ACTION_AWARE_APPLEWATCH_SYNC_PROGRESS   = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SYNC_PROGRESS"
    public static var EXTRA_LABEL  = "label"
    public static let EXTRA_STATUS = "status"
    public static let EXTRA_ERROR  = "error"
    
    
    public static let ACTION_AWARE_APPLEWATCH_RUNNING  = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_RUNNING"
    
    
    // flags for each sensor
    public static let ACTION_AWARE_APPLEWATCH_SYNC_MOTION       = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SENSOR_SYNC_MOTION"
    public static let ACTION_AWARE_APPLEWATCH_SYNC_NOISE        = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SENSOR_SYNC_NOISE"
    public static let ACTION_AWARE_APPLEWATCH_SYNC_AUDIOCLASS   = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SENSOR_SYNC_AUDIOCLASS"
    public static let ACTION_AWARE_APPLEWATCH_SYNC_BLUETOOTH    = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SENSOR_SYNC_BLUETOOTH"
    public static let ACTION_AWARE_APPLEWATCH_SYNC_HR           = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SENSOR_SYNC_HR"
    public static let ACTION_AWARE_APPLEWATCH_SYNC_LOCATION     = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SENSOR_SYNC_LOCATION"
    public static let ACTION_AWARE_APPLEWATCH_SYNC_BATTERY      = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SENSOR_SYNC_BATTERY"
    public static let ACTION_AWARE_APPLEWATCH_SYNC_HEADING      = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SENSOR_SYNC_HEADING"
    
    
    public static let ACTION_AWARE_APPLEWATCH_SYNC_COMPLETION_MOTION     = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SENSOR_SYNC_COMPLETION_MOTION"
    public static let ACTION_AWARE_APPLEWATCH_SYNC_COMPLETION_NOISE      = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SENSOR_SYNC_COMPLETION_NOISE"
    public static let ACTION_AWARE_APPLEWATCH_SYNC_COMPLETION_AUDIOCLASS = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SENSOR_SYNC_COMPLETION_AUDIOCLASS"
    public static let ACTION_AWARE_APPLEWATCH_SYNC_COMPLETION_BLUETOOTH  = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SENSOR_SYNC_COMPLETION_BLUETOOTH"
    public static let ACTION_AWARE_APPLEWATCH_SYNC_COMPLETION_HR         = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SENSOR_SYNC_COMPLETION_HR"
    public static let ACTION_AWARE_APPLEWATCH_SYNC_COMPLETION_LOCATION   = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SENSOR_SYNC_COMPLETION_LOCATION"
    public static let ACTION_AWARE_APPLEWATCH_SYNC_COMPLETION_BATTERY    = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SENSOR_SYNC_COMPLETION_BATTERY"
    public static let ACTION_AWARE_APPLEWATCH_SYNC_COMPLETION_HEADING    = "com.awareframework.ios.sensor.applewatch.ACTION_AWARE_APPLEWATCH_SENSOR_SYNC_COMPLETION_HEADING"
    
}




extension AppleWatchSensor: WCSessionDelegate  {
    

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        lastCommunicationMessageAt = Date()
        lastCommunicationError = error?.localizedDescription
    }
    
    public func sessionDidBecomeInactive(_ session: WCSession) {
    }
    
    public func sessionDidDeactivate(_ session: WCSession) {
    }
    
    public func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let fileName = file.fileURL.lastPathComponent
        fileProcessingQueue.async { [weak self] in
            self?.didReceive(file: file)
        }

        guard session.isReachable else { return }
        session.sendMessage(
            [
                "event_name": "file_transfer_completion",
                "file_path": fileName,
            ],
            replyHandler: { [weak self] _ in
                self?.lastCommunicationMessageAt = Date()
            },
            errorHandler: { [weak self] error in
                self?.lastCommunicationError = error.localizedDescription
            }
        )
    }
    
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        lastCommunicationMessageAt = Date()
        messageHandler?(message)
        if let status = message["status"] as? Int {
            if (status == 1) {
                isWatchCollectingData = true
                NotificationCenter.default.post(name: Notification.Name.actionAwareAppleWatchRunning, object: nil, userInfo: [AppleWatchSensor.EXTRA_STATUS: 1])
            }else{
                isWatchCollectingData = false
                NotificationCenter.default.post(name: Notification.Name.actionAwareAppleWatchRunning, object: nil, userInfo: [AppleWatchSensor.EXTRA_STATUS: 0])
            }
        }
    }
    
    public func session(_ session: WCSession,
                        didReceiveApplicationContext applicationContext: [String : Any]) {
        lastCommunicationMessageAt = Date()
        messageHandler?(applicationContext)
    }
    
    public func session(_ session: WCSession,
                              didReceiveMessage message: [String : Any],
                              replyHandler: @escaping ([String : Any]) -> Void) {
        didReceive(message: message, replyHandler: replyHandler)
    }
    
}

#elseif os(watchOS)

#endif
