import WatchConnectivity
import com_awareframework_ios_sensor_core
import DataCompression

public class AppleWatchSensor: AwareSensor {
    
    public static let TAG = "AWARE::AppleWatch"
    public var CONFIG:AppleWatchSensor.Config = Config()
    public var isWatchCollectingData = false
    
    var LAST_ACTIVITY = AppleWatchMotionData()
    
    private var syncCompletion = SyncCompletionWatch()
    
    public class Config:SensorConfig{
            
        public var fileTransferIntervalSeconds:Double = 60 * 15 // 15 minutes
        
        public var motionSensorHz:Int = 100 
        public var sensorObserver:AppleWatchObserver?
        
        public var keepOriginalFileFromWatch:Bool = false
        
        public override init() {
            super.init()
            dbPath = "aware_applewatch"
        }
        
        public override func set(config: Dictionary<String, Any>) {
            super.set(config: config)
            if let interval = config["motion_sensor_hz"] as? Int {
                self.motionSensorHz = interval
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
                                                selector: #selector(self.completeDataSyncOneSensor),
                                                name: name,
                                                object: nil)
        }
        
    }
    
    public override func start(){
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    public override func stop(){

    }
    
    public override func sync(force: Bool = false) {
        if let engine = self.dbEngine {
            
            syncCompletion = SyncCompletionWatch()
            
            self.notificationCenter.post(name: .actionAwareAppleWatchSync , object: self)
            
            // AppleWatchAcclerometer
            engine.startSync(AppleWatchMotionData.TABLE_NAME ,
                             AppleWatchMotionData.self,
                             DbSyncConfig().apply{config in
                config.debug = self.CONFIG.debug
                config.compactDataFormat = true
                config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.applewatch_motion.sync.queue")
                config.completionHandler = { (status, error) in
                    var userInfo: Dictionary<String,Any> = [AppleWatchSensor.EXTRA_STATUS :status]
                    if let e = error {
                        userInfo[AppleWatchSensor.EXTRA_ERROR] = e
                    }
                    self.notificationCenter.post(name: .actionAwareAppleWatchSyncCompletionMotion,
                                                 object: self,
                                                 userInfo:userInfo)
                }
            })
            
            engine.startSync(AppleWatchAudioData.TABLE_NAME,
                             AppleWatchAudioData.self,
                             DbSyncConfig().apply{ config in
                config.debug = self.CONFIG.debug
                config.compactDataFormat = true
                config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.applewatch_noise.sync.queue")
                config.completionHandler = {(status, error) in
                    var userInfo: Dictionary<String,Any> = [AppleWatchSensor.EXTRA_STATUS: status]
                    if let e = error {
                        userInfo[AppleWatchSensor.EXTRA_ERROR] = e
                    }
                    self.notificationCenter.post(name: .actionAwareAppleWatchSyncCompletionNoise,
                                                 object: self,
                                                 userInfo: userInfo)
                }
            })
            
            engine.startSync(AppleWatchAudioClassifierData.TABLE_NAME, AppleWatchAudioClassifierData.self, DbSyncConfig().apply {config in
                config.debug = self.CONFIG.debug
                config.compactDataFormat = true
                config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.applewatch_audioclass.sync.queue")
                config.completionHandler = {(status, error) in
                    var userInfo: Dictionary<String, Any> = [AppleWatchSensor.EXTRA_STATUS: status]
                    if let e = error {
                        userInfo[AppleWatchSensor.EXTRA_ERROR] = e
                    }
                    self.notificationCenter.post(name: .actionAwareAppleWatchSyncCompletionAudioClass,
                                                 object: self,
                                                 userInfo: userInfo)
                }
            })
            
            engine.startSync(AppleWatchHeartRateData.TABLE_NAME, AppleWatchHeartRateData.self, DbSyncConfig().apply {config in
            
                config.debug = self.CONFIG.debug
                config.compactDataFormat = true
                config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.applewatch_hr.sync.queue")
                config.completionHandler = {(status, error) in
                    var userInfo: Dictionary<String, Any> = [AppleWatchSensor.EXTRA_STATUS: status]
                    if let e = error {
                        userInfo[AppleWatchSensor.EXTRA_ERROR] = e
                    }
                    self.notificationCenter.post(name: .actionAwareAppleWatchSyncCompletionHR, object: self, userInfo: userInfo)
                }
            })
            
            engine.startSync(AppleWatchLocationData.TABLE_NAME, AppleWatchLocationData.self, DbSyncConfig().apply {config in
            
                config.debug = self.CONFIG.debug
                config.compactDataFormat = true
                config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.applewatch_location.sync.queue")
                config.completionHandler = {(status, error) in
                    var userInfo: Dictionary<String, Any> = [AppleWatchSensor.EXTRA_STATUS: status]
                    if let e = error {
                        userInfo[AppleWatchSensor.EXTRA_ERROR] = e
                    }
                    self.notificationCenter.post(name: .actionAwareAppleWatchSyncCompletionLocation, object: self, userInfo: userInfo)
                }
            })
            
            engine.startSync(AppleWatchHeadingData.TABLE_NAME, AppleWatchHeadingData.self, DbSyncConfig().apply {config in
            
                config.debug = self.CONFIG.debug
                config.compactDataFormat = true
                config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.applewatch_heading.sync.queue")
                config.completionHandler = {(status, error) in
                    var userInfo: Dictionary<String, Any> = [AppleWatchSensor.EXTRA_STATUS: status]
                    if let e = error {
                        userInfo[AppleWatchSensor.EXTRA_ERROR] = e
                    }
                    self.notificationCenter.post(name: .actionAwareAppleWatchSyncCompletionHeading, object: self, userInfo: userInfo)
                }
            })
            
            engine.startSync(AppleWatchBatteryData.TABLE_NAME, AppleWatchBatteryData.self, DbSyncConfig().apply {config in
                config.debug = self.CONFIG.debug
                config.compactDataFormat = true
                config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.applewatch_battery.sync.queue")
                config.completionHandler = {(status, error) in
                    var userInfo: Dictionary<String, Any> = [AppleWatchSensor.EXTRA_STATUS: status]
                    if let e = error {
                        userInfo[AppleWatchSensor.EXTRA_ERROR] = e
                    }
                    self.notificationCenter.post(name: .actionAwareAppleWatchSyncCompletionBattery, object: self, userInfo: userInfo)
                }
            })
            
            engine.startSync(AppleWatchBluetoothData.TABLE_NAME, AppleWatchBluetoothData.self, DbSyncConfig().apply {config in
                config.debug = self.CONFIG.debug
                config.compactDataFormat = true
                config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.applewatch_bluetooth.sync.queue")
                config.completionHandler = {(status, error) in
                    var userInfo: Dictionary<String, Any> = [AppleWatchSensor.EXTRA_STATUS: status]
                    if let e = error {
                        userInfo[AppleWatchSensor.EXTRA_ERROR] = e
                    }
                    self.notificationCenter.post(name: .actionAwareAppleWatchSyncCompletionBluetooth, object: self, userInfo: userInfo)
                }
            })
            
            
        }
    }
    
    private class SyncCompletionWatch {
        var motion = false
        var noise  = false
        var audioClass = false
        var location = false
        var hr = false
        var battery = false
        var heading = false
        var bluetooth = false
        
        func isCompleted() -> Bool {
            if (motion && noise && audioClass && location && hr && battery && heading && bluetooth) {
                return true
            }
            return false
        }
        
        func progress() -> Double {
            let sensors = [motion, noise, audioClass, location, hr, battery, heading, bluetooth]
            let sensorCount = Double(sensors.count)
            
            var total = 0.0
            for s in sensors {
                if (s == true) {
                    total += 1.0
                }
            }
            
            return total/sensorCount
        
             
        }
    }
    
    @objc func completeDataSyncOneSensor(notification: NSNotification) {
        
        if (notification.name == .actionAwareAppleWatchSyncCompletionMotion) {
            self.syncCompletion.motion = true
        }else if (notification.name == .actionAwareAppleWatchSyncCompletionHR) {
            self.syncCompletion.hr = true
        }else if (notification.name == .actionAwareAppleWatchSyncCompletionNoise) {
            self.syncCompletion.noise = true
        }else if (notification.name == .actionAwareAppleWatchSyncCompletionHeading) {
            self.syncCompletion.heading = true
        }else if (notification.name == .actionAwareAppleWatchSyncCompletionBattery) {
            self.syncCompletion.battery = true
        }else if (notification.name == .actionAwareAppleWatchSyncCompletionLocation) {
            self.syncCompletion.location = true
        }else if (notification.name == .actionAwareAppleWatchSyncCompletionBluetooth) {
            self.syncCompletion.bluetooth = true
        }else if (notification.name == .actionAwareAppleWatchSyncCompletionAudioClass){
            self.syncCompletion.audioClass = true
        }

        if (self.CONFIG.debug) {
            print("Sync Progress: ", self.syncCompletion.progress(), notification)
        }
        
        if (self.syncCompletion.isCompleted()){
            self.notificationCenter.post(name: .actionAwareAppleWatchSyncCompletion,
                                         object: self,
                                         userInfo: nil)
            self.syncCompletion = SyncCompletionWatch()
        }else{
            self.notificationCenter.post(name: .actionAwareAppleWatchSyncProgress,
                                         object: self,
                                         userInfo: [AppleWatchSensor.EXTRA_LABEL:self.syncCompletion.progress()])
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
    

    
    public func didReceive(file: WCSessionFile) {
        do {
        
            let newPath = createFileUrl(fileName: file.fileURL.lastPathComponent)
            try FileManager.default.copyItem(at: file.fileURL, to: newPath)
            
            print("\(#function): \(file.fileURL.lastPathComponent) -> received" )
            
            let data = try Data(contentsOf: newPath)
            if let decompressedData = data.decompress(withAlgorithm: .zlib) {
                if (CONFIG.keepOriginalFileFromWatch) {
                    var originalFilePath = newPath.lastPathComponent
                    let result = originalFilePath.range(of: ".zlib")
                    if let theRange = result {
                        originalFilePath.removeSubrange(theRange)
                        let originalFileUrl = createFileUrl(fileName: originalFilePath)
                        try decompressedData.write(to: originalFileUrl)
                        if let observer = self.CONFIG.sensorObserver {
                            observer.didReceive(file: originalFileUrl)
                        }
                    }
                }
                let components = newPath.lastPathComponent.split(separator: "_")
                if (components.count > 0) {
                    if (components[0] == "ambient") {
                        saveAmbientNoiseData(data: decompressedData, path: newPath)
                    } else if (components[0] == "motion"){
                        saveMotionData(data: decompressedData, path: newPath)
                    } else if (components[0] == "healthkit") {
                       saveHealthKitData(data: decompressedData, path: newPath)
                    } else if (components[0] == "audio") {
                        saveRawAudioData(data:decompressedData, path:newPath)
                    } else if (components[0] == "battery") {
                        saveBatteryData(data:decompressedData, path:newPath)
                    } else if (components[0] == "location") {
                        saveLocationData(data:decompressedData, path:newPath)
                    } else if (components[0] == "heading") {
                        saveHeadingData(data:decompressedData, path:newPath)
                    } else if (components[0] == "audio-classifier"){
                        saveAudioClassifierData(data:decompressedData, path:newPath)
                    } else if (components[0] == "bluetooth") {
                        saveBluetoothData(data:decompressedData, path:newPath)
                    }
                }
            }else {
                print("\(#function): \(file.fileURL.lastPathComponent) -> null")
            }
        }catch {
            print(error)
        }
    }
    
    
    
    public func didReceive(message: [String : Any],
                           replyHandler: @escaping ([String : Any]) -> Void) {
        if let method = message["method"] as? String {
            if (method == "get_settings") {
                replyHandler(
                    ["motion_sensor_hz":self.CONFIG.motionSensorHz,
                     "file_transfer_interval_seconds": self.CONFIG.fileTransferIntervalSeconds]
                )
            }
        }
    }
        
}

extension AppleWatchSensor {
    
    private func saveLocationData(data decompressedData:Data, path:URL){
//        "timestamp",
//        "latitude",
//        "longitude",
//        "altitude",
//        "ellipsoidal_altitude",
//        "horizontal_accuracy",
//        "vertical_accuracy",
//        "speed",
//        "speed_accuracy",
//        "course",
//        "course_accuracy",
//        "label"
        
        let decompressedDataStr = String(data: decompressedData, encoding: .utf8)
        let csvLines = decompressedDataStr!.components(separatedBy: .newlines)
        var buffer:[AppleWatchLocationData] = []

        var isHeader = true

        for line in csvLines {
            if (isHeader) {
                isHeader = false
                continue
            }

            let elements = line.components(separatedBy: ",")
            if (elements.count < 12) {
                continue
            }

            let watchLocationData = AppleWatchLocationData()
            let timestamp = Int64(Double(elements[0]) ?? 0)
            watchLocationData.timestamp = timestamp
            watchLocationData.latitude = Double(elements[1]) ?? 0
            watchLocationData.longitude = Double(elements[2]) ?? 0
            watchLocationData.altitude = Double(elements[3]) ?? 0
            watchLocationData.ellipsoidal_altitude = Double(elements[4]) ?? 0
            watchLocationData.horizontal_accuracy = Double(elements[5]) ?? 0
            watchLocationData.vertical_accuracy = Double(elements[6]) ?? 0
            watchLocationData.speed = Double(elements[7]) ?? 0
            watchLocationData.speed_accuracy = Double(elements[8]) ?? 0
            watchLocationData.course = Double(elements[9]) ?? 0
            watchLocationData.course_accuracy = Double(elements[10]) ?? 0
            watchLocationData.label = CONFIG.label
            // self.CONFIG.sensorObserver?.onBatteryChanged(data: watchBatteryData.toDictionary())

            buffer.append(watchLocationData)

            if buffer.count > 100 {
                dbEngine?.save(buffer)
                buffer.removeAll()
            }
        }
        dbEngine?.save(buffer)
        do {
            try FileManager.default.removeItem(at: path)
        } catch {
            print(error)
        }
    }

    private func saveHeadingData(data decompressedData:Data, path:URL){

        let decompressedDataStr = String(data: decompressedData, encoding: .utf8)
        let csvLines = decompressedDataStr!.components(separatedBy: .newlines)
        var buffer:[AppleWatchHeadingData] = []

        var isHeader = true

        for line in csvLines {
            if (isHeader) {
                isHeader = false
                continue
            }

            let elements = line.components(separatedBy: ",")
            if (elements.count < 8) {
                continue
            }

            let watchHeadingData = AppleWatchHeadingData()
            let timestamp = Int64(Double(elements[0]) ?? 0)
            watchHeadingData.timestamp = timestamp
            watchHeadingData.true_heading = Double(elements[1]) ?? 0
            watchHeadingData.magnetic_heading = Double(elements[2]) ?? 0
            watchHeadingData.heading_accuracy = Double(elements[3]) ?? 0
            watchHeadingData.x = Double(elements[4]) ?? 0
            watchHeadingData.y = Double(elements[5]) ?? 0
            watchHeadingData.z = Double(elements[6]) ?? 0
            watchHeadingData.label = CONFIG.label
            // self.CONFIG.sensorObserver?.onBatteryChanged(data: watchBatteryData.toDictionary())

            buffer.append(watchHeadingData)

            if buffer.count > 100 {
                dbEngine?.save(buffer)
                buffer.removeAll()
            }
        }
        dbEngine?.save(buffer)
        do {
            try FileManager.default.removeItem(at: path)
        } catch {
            print(error)
        }
    }
    
    private func saveBatteryData(data decompressedData:Data, path:URL){
        let decompressedDataStr = String(data: decompressedData, encoding: .utf8)
        let csvLines = decompressedDataStr!.components(separatedBy: .newlines)
        var buffer:[AppleWatchBatteryData] = []
        
        var isHeader = true
        
        for line in csvLines {
            if (isHeader) {
                isHeader = false
                continue
            }
            
            let elements = line.components(separatedBy: ",")
            if (elements.count < 3) {
                continue
            }
            
            let watchBatteryData = AppleWatchBatteryData()
            let timestamp = Int64(Double(elements[0]) ?? 0)
            watchBatteryData.timestamp = timestamp
            watchBatteryData.battery_level = Double(elements[1]) ?? 0
            watchBatteryData.battery_state = Int(elements[2]) ?? 0
            watchBatteryData.label = CONFIG.label
            // self.CONFIG.sensorObserver?.onBatteryChanged(data: watchBatteryData.toDictionary())
            
            buffer.append(watchBatteryData)

        }
        dbEngine?.save(buffer)
        do {
            try FileManager.default.removeItem(at: path)
        } catch {
            print(error)
        }
    }
    
    private func saveAmbientNoiseData(data decompressedData:Data, path:URL){
        let decompressedDataStr = String(data: decompressedData, encoding: .utf8)
        let csvLines = decompressedDataStr!.components(separatedBy: .newlines)
        var buffer:[AppleWatchAudioData] = []
        
        var isHeader = true
        
        for line in csvLines {
            if (isHeader) {
                isHeader = false
                continue
            }
            
            let elements = line.components(separatedBy: ",")
            if (elements.count < 2) {
                continue
            }
            
            let watchAudioData = AppleWatchAudioData()
            let timestamp = Int64(Double(elements[0]) ?? 0)
            watchAudioData.timestamp = timestamp
            watchAudioData.decibel = Double(elements[1]) ?? 0
            watchAudioData.label = CONFIG.label
            self.CONFIG.sensorObserver?.onAudioChanged(data: watchAudioData.toDictionary())
            
            buffer.append(watchAudioData)
            if buffer.count > 100 {
                dbEngine?.save(buffer)
                buffer.removeAll()
            }
        }
        dbEngine?.save(buffer)
        do {
            try FileManager.default.removeItem(at: path)
        } catch {
            print(error)
        }
    }
    
    private func saveMotionData(data decompressedData:Data, path:URL) {
        let decompressedDataStr = String(data: decompressedData, encoding: .utf8)
        let csvLines = decompressedDataStr!.components(separatedBy: .newlines)
        var buffer:[AppleWatchMotionData] = []
        var isHeader = true
        
        for line in csvLines {
            if (isHeader) {
                isHeader = false
                continue
            }

            let elements = line.components(separatedBy: ",")
            if (elements.count < 15) {
                continue
            }

            let watchData = AppleWatchMotionData()
            watchData.timestamp = Int64(Double(elements[0]) ?? 0)
            watchData.acc_x = Double(elements[1]) ?? 0
            watchData.acc_y = Double(elements[2]) ?? 0
            watchData.acc_z = Double(elements[3]) ?? 0
            watchData.roll = Double(elements[4]) ?? 0
            watchData.pitch = Double(elements[5]) ?? 0
            watchData.yaw = Double(elements[6]) ?? 0
            watchData.gravity_x = Double(elements[7]) ?? 0
            watchData.gravity_y = Double(elements[8]) ?? 0
            watchData.gravity_z = Double(elements[9]) ?? 0
            watchData.rotation_x = Double(elements[10]) ?? 0
            watchData.rotation_y = Double(elements[11]) ?? 0
            watchData.rotation_z = Double(elements[12]) ?? 0
            watchData.user_acc_x = Double(elements[13]) ?? 0
            watchData.user_acc_y = Double(elements[14]) ?? 0
            watchData.user_acc_z = Double(elements[15]) ?? 0
            watchData.label = CONFIG.label
            
            self.CONFIG.sensorObserver?.onMotionChanged(data: watchData.toDictionary())
            
            buffer.append(watchData)
            if buffer.count > 10000 {
                dbEngine?.save(buffer)
                buffer.removeAll()
            }
        }
        
        dbEngine?.save(buffer)
        
        do {
            try FileManager.default.removeItem(at: path)
        }catch {
            print(error)
        }
    }
    
    private func saveHealthKitData(data decompressedData:Data, path:URL) {
        let decompressedDataStr = String(data: decompressedData, encoding: .utf8)
        let csvLines = decompressedDataStr!.components(separatedBy: .newlines)
        var buffer:[AppleWatchHeartRateData] = []
        var isHeader = true
        for line in csvLines {
            if (isHeader) {
                isHeader = false
                continue
            }

            let elements = line.components(separatedBy: ",")
            if (elements.count < 2) {
                continue
            }

            let watchData = AppleWatchHeartRateData()
            watchData.timestamp = Int64(Double(elements[0]) ?? 0)
            watchData.hr = Double(elements[1]) ?? 0
            watchData.label = CONFIG.label
            self.CONFIG.sensorObserver?.onHeartRateChanged(data: watchData.toDictionary())
            
            buffer.append(watchData)
            if buffer.count > 100 {
                dbEngine?.save(buffer)
                buffer.removeAll()
            }
        }
        
        dbEngine?.save(buffer)
        do {
            try FileManager.default.removeItem(at: path)
        }catch {
            print(error)
        }
    }
    
    private func saveRawAudioData(data decompressedData:Data,path:URL) {
        let watchAudioFileData = AppleWatchAudioFileData()
        watchAudioFileData.timestamp = Int64(Date().timeIntervalSince1970 * 1000.0)
        watchAudioFileData.file_name = path.lastPathComponent;
        dbEngine?.save(watchAudioFileData)
        
        let rawAudioFile = createFileUrl(fileName: path.lastPathComponent.split(separator: ".")[0]+".m4a")
        do {
            try decompressedData.write(to: rawAudioFile)
        }catch{
            print(error)
        }
        
        self.CONFIG.sensorObserver?.onAudioFileReceived(data: rawAudioFile)
        
        do {
            try FileManager.default.removeItem(at: path)
        }catch{
            print(error)
        }
    }
    
    
    private func saveAudioClassifierData(data decompressedData: Data, path:URL){
        let decompressedDataStr = String(data: decompressedData, encoding: .utf8)
        let csvLines = decompressedDataStr!.components(separatedBy: .newlines)
        var buffer:[AppleWatchAudioClassifierData] = []
        
        var isHeader = true
        
        for line in csvLines {
            if (isHeader) {
                isHeader = false
                continue
            }
            
            let elements = line.components(separatedBy: ",")
            if (elements.count < 2) {
                continue
            }
            
            let watchAudioData = AppleWatchAudioClassifierData()
            let timestamp = Int64(Double(elements[0]) ?? 0)
            watchAudioData.timestamp = timestamp
            watchAudioData.confidence = Double(elements[2]) ?? 0
            watchAudioData.identifier = String(elements[1])
            watchAudioData.label = CONFIG.label
//            self.CONFIG.sensorObserver?.onAudioChanged(data: watchAudioData.toDictionary())
            
            buffer.append(watchAudioData)
            if buffer.count > 100 {
                dbEngine?.save(buffer)
                buffer.removeAll()
            }
        }
        dbEngine?.save(buffer)
        do {
            try FileManager.default.removeItem(at: path)
        } catch {
            print(error)
        }
    }
    
    
    
    private func saveBluetoothData(data decompressedData: Data, path:URL){
        let decompressedDataStr = String(data: decompressedData, encoding: .utf8)
        let csvLines = decompressedDataStr!.components(separatedBy: .newlines)
        var buffer:[AppleWatchBluetoothData] = []
        
        var isHeader = true
        
        for line in csvLines {
            if (isHeader) {
                isHeader = false
                continue
            }
            
            let elements = line.components(separatedBy: ",")
            if (elements.count < 2) {
                continue
            }
            
            let data = AppleWatchBluetoothData()
            let timestamp = Int64(Double(elements[0]) ?? 0)
            data.timestamp = timestamp
            data.identifier = String(elements[1])
            data.name = String(elements[2])
            data.rssi = Double(elements[3]) ?? 0
            data.label = CONFIG.label
                        
            buffer.append(data)
            if buffer.count > 100 {
                dbEngine?.save(buffer)
                buffer.removeAll()
            }
        }
        dbEngine?.save(buffer)
        do {
            try FileManager.default.removeItem(at: path)
        } catch {
            print(error)
        }
    }
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
    }
    
    public func sessionDidBecomeInactive(_ session: WCSession) {
    }
    
    public func sessionDidDeactivate(_ session: WCSession) {
    }
    
    public func session(_ session: WCSession, didReceive file: WCSessionFile) {
        didReceive(file: file)
        
        WCSession.default.sendMessage(["event_name":"file_transfer_completion",
                                       "file_path":file.fileURL.lastPathComponent])
        { respMsg in
            print("\(#function): \(respMsg.debugDescription)")
        }
    }
    
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
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
                              didReceiveMessage message: [String : Any],
                              replyHandler: @escaping ([String : Any]) -> Void) {
        didReceive(message: message, replyHandler: replyHandler)
    }
    
}


