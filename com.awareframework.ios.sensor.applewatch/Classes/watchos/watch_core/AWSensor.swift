import HealthKit
import CoreML
import UserNotifications
import WatchConnectivity
import DataCompression
import AVFoundation

public class AWSensorConfig {
    public var enabled:Bool    = false
    public var debug:Bool      = false
    public var label:String    = ""
    public var motionSensorHz  = 100
    public var activateMotionSensor = false
    public var activateHRSensor = false
    public var activateAmbientNoiseSensor = false
    public var activateRawAudioSensor = false
    public var activateBatterySensor = false
    public var activateLocationSensor = false
    public var activateHeadingSensor = false
    public var activateAudioClassificationSensor = false
    public var activateBluetoothSensor = false
    
    public var useLocalConfig = true
    
    public var autoFileTransfer = true
    public var autoFileTransferInterval = 60 * 15 // 15 minutes
    public var autoRecoveryFileTransfer = true
    
    public var audioBufferHandler:AVAudioNodeTapBlock?
    public var audioClassifierModel:MLModel?
    
    public var audioSensorConfig = AWAudioSensorConfig()
    
    public var useWorkoutSession = false
    
    public init(){
        
    }
    
    public func apply(closure:(_ config: AWSensorConfig) -> Void) -> Self {
        closure(self)
        return self
    }
}

public class AWSensor: NSObject {
    
    public static let shared = AWSensor()
    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    public var config = AWSensorConfig()

    public let motionSensor     = AWMotionSensor()
    public let audioSensor      = AWAudioSensor()
    public let hrSensor         = AWHealthKitSensor()
    public let batterySensor    = AWBatterySensor()
    public let locationSensor   = AWLocationSensor()
    public let bluetoothSensor  = AWBluetoothSensor()

    let healthStore:HKHealthStore = HKHealthStore()
    var session : HKWorkoutSession?
    
    let transferManager:FileTransferManager = FileTransferManager()
    private var recoveryFileTransferTimer:Timer? = nil
    
    public func start(_ config:AWSensorConfig){
        self.config = config
        
        if (self.config.useLocalConfig){
            DispatchQueue.main.async {
                if (config.useWorkoutSession) {
                    self.startWorkout()
                }
                if (config.activateMotionSensor) {
                    self.motionSensor.start(config)
                }
                if (config.activateAmbientNoiseSensor || config.activateRawAudioSensor || config.activateAudioClassificationSensor) {
                    self.audioSensor.start(config)
                }
                if (config.activateHRSensor ) {
                    self.hrSensor.start(config)
                }
                if (config.activateBatterySensor) {
                    self.batterySensor.start(config)
                }
                if (config.activateLocationSensor || config.activateHeadingSensor) {
                    self.locationSensor.start(config)
                }
                if (config.activateBluetoothSensor) {
                    self.bluetoothSensor.start(config)
                }
            }
        }else{
            getSettings({settings in
                if (self.config.debug) {
                    print("[AWSensor][settings]\(settings)")
                }
                DispatchQueue.main.async {
                    if (config.useWorkoutSession) {
                        self.startWorkout()
                    }
                    if let hz = settings["motion_sensor_hz"] as? Int {
                        config.motionSensorHz = hz
                    }
                    if let ftInterval = settings["file_transfer_interval_seconds"] as? Int{
                        config.autoFileTransferInterval = ftInterval
                    }
                    
                    if (config.activateMotionSensor) {
                        self.motionSensor.start(config)
                    }
                    if (config.activateAmbientNoiseSensor || config.activateRawAudioSensor || config.activateAudioClassificationSensor) {
                        self.audioSensor.start(config)
                    }
                    if (config.activateHRSensor ) {
                        self.hrSensor.start(config)
                    }
                    if (config.activateBatterySensor) {
                        self.batterySensor.start(config)
                    }
                    if (config.activateLocationSensor || config.activateHeadingSensor) {
                        self.locationSensor.start(config)
                    }
                    if (config.activateBluetoothSensor) {
                        self.bluetoothSensor.start(config)
                    }
                }
            })
        }
        
        
        if(config.autoRecoveryFileTransfer) {
            DispatchQueue.main.async {
                let hour = 60*60
                if (self.recoveryFileTransferTimer == nil) {
                    self.recoveryFileTransferTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(hour) , repeats: true, block: { timer in
                        self.recoveryFileTransfer()
                    })
                }
            }
        }
        WCSession.default.sendMessage(["status":1], replyHandler: nil)
    }
    
    public func stop(){
        motionSensor.stop()
        audioSensor.stop()
        hrSensor.stop()
        batterySensor.stop()
        locationSensor.stop()
        bluetoothSensor.stop()
        stopWorkout()
        if let timer = recoveryFileTransferTimer {
            timer.invalidate()
            recoveryFileTransferTimer = nil
        }
        WCSession.default.sendMessage(["status":0], replyHandler: nil)
    }
    
    
    public func removeSensorDataFile(_ fileName:String) {
        let fileManager = FileManager.default
        let docDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePath = docDir.appendingPathComponent(fileName)
        if (filePath.isFileURL) {
            do {
                try fileManager.removeItem(at: filePath)
            } catch {
                print("\(#function): \(error.localizedDescription)")
            }
        }
    }
    
    public func getAllSensorDataFiles() -> [URL] {
        do {
            let fileManager = FileManager.default
            let docDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let files = try fileManager.contentsOfDirectory(at: docDir, includingPropertiesForKeys: [])
            return files
        }catch {
            print("\(#function):error: \(error.localizedDescription)")
        }
        return []
    }
    
    
    public func recoveryFileTransfer(){
        if (self.config.debug) { print(#function) }
        cancelAllFileTransferProcesses()
        startFileTransferProcessesWithUnsycnedFiles()

    }
    
    public func cancelAllFileTransferProcesses(){
        // NOTE: cancel all sync progress
        for fileTransfer in WCSession.default.outstandingFileTransfers {
            fileTransfer.progress.cancel()
            fileTransfer.cancel()
            if (config.debug) {
                print("\(#function): \(fileTransfer.file.fileURL.lastPathComponent) = \(fileTransfer.progress.isIndeterminate), \(fileTransfer.progress.isPaused), \(fileTransfer.progress.isCancelled), \(fileTransfer.progress.isFinished)" )
            }
        }

    }
    
    public func startFileTransferProcessesWithUnsycnedFiles(){
        for file in getUntransferredFiles() {
            if (config.debug) {
                print("\(#function): \(file.lastPathComponent)")
            }
            self.transferFile(file)
        }
    }
    
    public func transferFile(_ file:URL){
        if (config.debug) {
            print("[Manual Sync] start sync -> \(file.lastPathComponent)")
        }

        let isCompressed = file.lastPathComponent.split(separator: ".").last ?? "" == "zlib"
        if isCompressed {
            transferManager.transferFile(fileURL: file, compression: false, debug: self.config.debug)
        }else{
            transferManager.transferFile(fileURL: file, compression: true, debug: self.config.debug)
        }
    }
    
    public func getUntransferredFiles(debug:Bool = false) -> [URL] {
        var untransferredFiles = [URL]()
        let storedSensorDataFiles = self.getAllSensorDataFiles()
       
        if (storedSensorDataFiles.count == 0 && debug) {
            print("\(#function) No un-transferred files")
        }

        for file in storedSensorDataFiles {
            var isCurrentWorkingFile = false
            for f in [motionSensor.sensorData,
                      hrSensor.sensorData,
                      audioSensor.sensorData,
                      audioSensor.audioClassifierData,
                      batterySensor.sensorData,
                      bluetoothSensor.sensorDataBluetooth,
                      locationSensor.sensorDataLocation,
                      locationSensor.sensorDataHeading
                ] {
                // print(file.lastPathComponent, f?.filePath.lastPathComponent ?? "")
                if (file.lastPathComponent == f?.filePath.lastPathComponent) {
                    isCurrentWorkingFile = true
                    break
                }
            }
            if isCurrentWorkingFile { continue }
            untransferredFiles.append(file)
        }
        if debug {
            print("\(#function) -> Untransferred Files = \(untransferredFiles.count)")
        }
        return untransferredFiles
    }
    
    public func getSettings(_ handler: (([String : Any]) -> Void)?){
        WCSession.default.sendMessage(["method":"get_settings"]) { settings in
            if let h = handler {
                h(settings)
            }
        }
    }
    
    func startWorkout() {
        if (session != nil) { return }
        
        // Configure the workout session.
        let workoutConfiguration = HKWorkoutConfiguration()
        workoutConfiguration.activityType = .other
        workoutConfiguration.locationType = .unknown
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: workoutConfiguration)
            if let uwSession = session {
                uwSession.delegate = self
                uwSession.startActivity(with: Date())
            }
        } catch {
            fatalError("Unable to create the workout session!")
        }
    }
    
    
    func stopWorkout(){
        if let workout = self.session {
            workout.end()
        }
        self.session = nil
    }
}

extension AWSensor {
    public func requestPermissionNotification(completion: @escaping (Bool, Error?) -> Void){
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.sound,.badge]) { (success, error) in
            completion(success, error)
        }
    }
    
    public func requestPermissionHealthKit(completion: @escaping (Bool, Error?) -> Void){
        hrSensor.initHealthKit { success, error in
            completion(success, error)
        }
    }
}


extension AWSensor: HKWorkoutSessionDelegate{

    public func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        switch toState {
        case .running:
            workoutDidStart(date)
        case .ended:
            workoutDidEnd(date)
        default:
            print("Unexpected state \(toState)")
        }
    }

    public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout error")
    }

    func workoutDidStart(_ date : Date) {
//        if let query = createHeartRateStreamingQuery(date) {
//            self.currenQuery = query
//            healthStore.execute(query)
//        } else {
//            // label.setText("cannot start")
//        }
    }

    func workoutDidEnd(_ date : Date) {
//        if let query = self.currenQuery{
//            healthStore.stop(query)
//            // label.setText("---")
//        }
//        session = nil
    }
}

extension AWSensor: WCSessionDelegate{
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if (config.debug) {
            switch activationState {
            case .notActivated:
                print("\(#function): notActivated")
            case .inactive:
                print("\(#function): inactive")
            case .activated:
                print("\(#function): activated")
            @unknown default:
                print("\(#function): unkwnon")
            }
        }
    }
    
    public func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        
        if let e = error {
            if config.debug {
                print("\(#function): did not complete the file transfer -> \(fileTransfer.file.fileURL.lastPathComponent) \(e.localizedDescription)")
            }
        }else{
            if config.debug {
                print("\(#function): complete the file transfer & remove a local file -> \(fileTransfer.progress.fractionCompleted) \(fileTransfer.file.fileURL.lastPathComponent)")
            }
            /// NOTE: 本体からのレスポンスがあった時のみ削除
//            if (fileTransfer.progress.isFinished) {
//                removeSensorDataFile(fileTransfer.file.fileURL.lastPathComponent)
//            }
        }
    }
    
//    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
//        print("\(#function): \(message.debugDescription)")
//        
//        guard let eventName = message["event_name"] as? String,
//                let filePath = message["file_path"] as? String else {
//            return
//        }
//        
//        print(eventName, filePath)
//    }
    
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("\(#function): \(message.debugDescription)")
        
        guard let eventName = message["event_name"] as? String,
                let fileName = message["file_path"] as? String else {
            return
        }
        
        if (eventName == "file_transfer_completion") {
            if (config.debug) { print("[Remove Synced File]: ", fileName) }
            removeSensorDataFile(fileName)
        }
    }
    
}

public class FileTransferManager {
    
    func transferFile(fileURL:URL, compression:Bool=true, debug:Bool=false) {
    
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if (FileManager.default.fileExists(atPath: fileURL.path)){
                    // ファイル圧縮を必要とする場合
                    if compression {
                        let d = try Data(contentsOf: fileURL)
                        let compressedFileName = fileURL.lastPathComponent + ".zlib"
                        let docsDirect = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    
                        let compressedFileURL = docsDirect.appendingPathComponent(compressedFileName)
                        try d.compress(withAlgorithm: .zlib)?.write(to: compressedFileURL)
                        
                        if debug {
                            print("\(fileURL.lastPathComponent): \(self.getFileSize(path: fileURL.path)) -> \(self.getFileSize(path: compressedFileURL.path))")
                        }
                        
                        DispatchQueue.main.async {
                            WCSession.default.transferFile(compressedFileURL, metadata: nil)
                        }
                        try FileManager.default.removeItem(at: fileURL)
                    // 既にファイルが圧縮済みの場合
                    }else{
                        if debug {
                            print("\(#function) -> transfer a file \(fileURL.lastPathComponent) without data compression")
                        }
                        DispatchQueue.main.async {
                            WCSession.default.transferFile(fileURL, metadata: nil)
                        }
                    }
                    
                }else{
                    if (debug) {
                        print("file does not exist -> \(fileURL.lastPathComponent)")
                    }
                }
            
            }catch {
                print(error)
            }
        }
    }
    
    private func getFileSize(path:String) -> UInt64 {
        do {
            let manager = FileManager.default
            let attributes = try manager.attributesOfItem(atPath: path) as NSDictionary
            return attributes.fileSize()
        }catch{
            return 0
        }

    }
}
