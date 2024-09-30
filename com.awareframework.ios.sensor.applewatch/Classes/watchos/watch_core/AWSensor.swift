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
    
    public var audioSensorConfig = AWAudioClassificationSensorConfig()
    
    
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

    public let motionSensor:AWMotionSensor = AWMotionSensor()
    public let audioSensor:AWAudioSensor = AWAudioSensor()
    public let hrSensor:AWHealthKitSensor = AWHealthKitSensor()
    public let batterySensor:AWBatterySensor = AWBatterySensor()
    public let locationSensor:AWLocationSensor = AWLocationSensor()
    public let bluetoothSensor:AWBluetoothSensor = AWBluetoothSensor()

    let healthStore:HKHealthStore = HKHealthStore()
    var session : HKWorkoutSession?
    
    let transferManager:FileTransferManager = FileTransferManager()
    private var recoveryFileTransferTimer:Timer? = nil
    
    public func start(_ config:AWSensorConfig){
        self.config = config
        
        if (self.config.useLocalConfig){
            DispatchQueue.main.async {
                self.startWorkout()
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
                    self.startWorkout()
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
    }
    
    public func recoveryFileTransfer(){
        if (self.config.debug) {
            print("[Manula Sync] start")
        }
        
        for file in getUntransferredFiles() {
            self.fileTransfer(file)
        }
    }
    
    public func fileTransfer(_ file:URL){
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
        do {
            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let files = try FileManager.default.contentsOfDirectory(at: docDir, includingPropertiesForKeys: [])
            
            if (files.count == 0 && debug) {
                print("[Manual Sync] no cache files")
            }

            for file in files {
                if (motionSensor.sensorData?.filePath.lastPathComponent == file.lastPathComponent){
                    continue
                }
                if (hrSensor.sensorData?.filePath.lastPathComponent == file.lastPathComponent) {
                    continue
                }
                if (audioSensor.sensorData?.filePath.lastPathComponent == file.lastPathComponent) {
                    continue
                }
                if (audioSensor.audioRecorder != nil) {
                    if (audioSensor.audioRecorder.url.lastPathComponent == file.lastPathComponent) {
                        continue
                    }
                }
                if (batterySensor.sensorData?.filePath.lastPathComponent == file.lastPathComponent) {
                    continue
                }
                
                var isTransferring = false
                let transferringFiles = WCSession.default.outstandingFileTransfers
                for tr in transferringFiles {
                    if (tr.file.fileURL == file && tr.isTransferring) {
                        isTransferring = true
                    }
                }
                if (isTransferring) {
                    if (debug){
                        print("\(#function) -> transferring file: \(file.lastPathComponent)")
                    }
                    continue;
                }
                if (debug) {
                    print("\(#function) -> untranfer file: \(file.lastPathComponent) ")
                }
                untransferredFiles.append(file)
            }
        } catch {
            print(error.localizedDescription)
        }
        if debug {
            print("\(#function) -> \(untransferredFiles.count)")
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
        print(#function)
        
        switch activationState {
        case .notActivated:
            print("notActivated")
        case .inactive:
            print("inactive")
        case .activated:
            print("activated")
        @unknown default:
            print("unkwnon")
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
            if (fileTransfer.progress.isFinished) {
                do {
                    try FileManager.default.removeItem(at: fileTransfer.file.fileURL)
                }catch{
                    print(error)
                }
            }
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
                        DispatchQueue.main.async {
                            if debug {
                                print("\(#function) -> transfer a file \(fileURL.lastPathComponent) withoud data compression")
                            }
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
