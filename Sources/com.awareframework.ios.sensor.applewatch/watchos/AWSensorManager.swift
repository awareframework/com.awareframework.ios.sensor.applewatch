import HealthKit
import CoreML
import UserNotifications
import WatchConnectivity
import AVFoundation

import com_awareframework_ios_core
import com_awareframework_ios_sensor_applewatch_shared

public class AWSensorManager: NSObject {
    
    public static let shared = AWSensorManager()
    private override init() {
        super.init()
    }

    public var sensors:[AwareSensor] = []
    
    let healthStore:HKHealthStore = HKHealthStore()
    #if os(watchOS)
    var session : HKWorkoutSession?
    private var backgroundAudioEngine: AVAudioEngine?
    private var isBackgroundAudioTapInstalled = false
    #endif
    public var debug = false
    
    public func set(sensors:[AwareSensor], _ handler:(()->Void)?) {
        self.clear {
            self.sensors = sensors
            handler?()
        }
    }
    
    public func clear(_ handler:(()->Void)?) {
        stop {
            self.sensors.removeAll()
            handler?()
        }
    }
    
    public func start(backgroundSessionType: AWBackgroundSessionType = .none, _ handler:(()->Void)?){
        DispatchQueue.main.async {
            for s in self.sensors {
                s.start()
            }
            self.startBackgroundSession(backgroundSessionType)
            WCSession.default.sendMessage(["status":1], replyHandler: nil)
            handler?()
        }
    }

    public func start(useWorkoutSession: Bool = false, _ handler:(()->Void)?){
        start(backgroundSessionType: useWorkoutSession ? .workout : .none, handler)
    }
    
    public func stop(_ handler:(()->Void)?){
        DispatchQueue.main.async {
            for s in self.sensors {
                s.stop()
            }
            self.stopBackgroundSession()
            WCSession.default.sendMessage(["status":0], replyHandler: nil)
            handler?()
        }
    }
    
    public func sync(force: Bool = false, dbHost:String? = nil){
        DispatchQueue.main.async {
            for s in self.sensors {
                if let url = dbHost {
                    s.dbEngine?.config.host = url
                }
                s.sync(force: true)
            }
        }
    }
}

/** workout sessions */
#if os(watchOS)
extension AWSensorManager: HKWorkoutSessionDelegate{

    func startBackgroundSession(_ type: AWBackgroundSessionType) {
        stopBackgroundSession()
        switch type {
        case .none:
            break
        case .workout:
            startWorkout()
        case .microphone:
            if hasActiveAudioCaptureSensor() {
                return
            }
            startMicrophoneSession()
        }
    }

    func stopBackgroundSession() {
        stopWorkout()
        stopMicrophoneSession()
    }

    func startWorkout() {
        if (session != nil) { return }
        
        // Configure the workout session.
        let workoutConfiguration = HKWorkoutConfiguration()
        workoutConfiguration.activityType = .other
        workoutConfiguration.locationType = .unknown
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore,
                                           configuration: workoutConfiguration)
            if let uwSession = session {
                uwSession.delegate = self
                uwSession.startActivity(with: Date())
            }
            
        } catch {
            if debug {
                print("AWARE::AppleWatch workout session error:", error)
            }
        }
    }
    
    
    func stopWorkout(){
        if let workout = self.session {
            workout.end()
        }
        self.session = nil
    }

    func startMicrophoneSession() {
        if backgroundAudioEngine != nil { return }

        let audioSession = AVAudioSession.sharedInstance()
        audioSession.requestRecordPermission { [weak self] granted in
            guard granted else { return }
            DispatchQueue.main.async {
                guard let self, self.backgroundAudioEngine == nil else { return }
                let audioEngine = AVAudioEngine()

                do {
                    try audioSession.setCategory(.record, mode: .default, options: [])
                    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

                    let inputNode = audioEngine.inputNode
                    let inputFormat = inputNode.inputFormat(forBus: 0)
                    guard inputFormat.channelCount > 0 else {
                        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                        return
                    }

                    inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) { _, _ in }
                    self.isBackgroundAudioTapInstalled = true
                    audioEngine.prepare()
                    try audioEngine.start()
                    self.backgroundAudioEngine = audioEngine
                } catch {
                    if self.debug {
                        print("AWARE::AppleWatch background microphone session error:", error)
                    }
                    if self.isBackgroundAudioTapInstalled {
                        audioEngine.inputNode.removeTap(onBus: 0)
                        self.isBackgroundAudioTapInstalled = false
                    }
                    audioEngine.stop()
                    audioEngine.reset()
                    try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                }
            }
        }
    }

    func stopMicrophoneSession() {
        guard let audioEngine = backgroundAudioEngine else { return }
        audioEngine.stop()
        if isBackgroundAudioTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isBackgroundAudioTapInstalled = false
        }
        audioEngine.reset()
        backgroundAudioEngine = nil

        if !hasActiveAudioCaptureSensor() {
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        }
    }

    private func hasActiveAudioCaptureSensor() -> Bool {
        sensors.contains { sensor in
            guard let audioSensor = sensor as? AWAudioSensor else { return false }
            return audioSensor.CONFIG.activateAmbientNoiseSensor
                || audioSensor.CONFIG.activateAudioClassificationSensor
                || audioSensor.CONFIG.activateRawAudioSensor
                || audioSensor.CONFIG.audioBufferHandler != nil
        }
    }
    
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
#else
extension AWSensorManager {
    func startBackgroundSession(_ type: AWBackgroundSessionType) {}

    func stopBackgroundSession() {}

    func startWorkout() {}
    
    func stopWorkout() {}
}
#endif

extension AWSensorManager {
    public func requestPermissionNotification(completion: @escaping (Bool, Error?) -> Void){
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.sound,.badge]) { (success, error) in
            completion(success, error)
        }
    }

    public func requestPermissionHealthKit(completion: @escaping (Bool, Error?) -> Void){
        for s in self.sensors {
            #if os(iOS)

            #elseif os(watchOS)
            if let hrSensor = s as? AWHeartRateSensor {
                hrSensor.initHealthKit { success, error in
                    completion(success, error)
                }
            }
            #endif
        }
    }
}

extension AWSensorManager {

    /// Transfer all locally stored sensor data to the paired iPhone.
    ///
    /// Every record in each sensor's database is included regardless of whether
    /// it has been transferred before.
    ///
    /// - Parameters:
    ///   - deleteAfterTransfer: When `true`, records are deleted from the watch-side
    ///     database after all file transfers complete successfully. Defaults to `false`.
    ///   - completion: Called on the main thread when all file transfers complete or
    ///     an error occurs.
    public func transferAllData(deleteAfterTransfer: Bool = false,
                                completion: ((Error?) -> Void)? = nil) {
        AWDataTransferManager.shared.transferMode = .all
        AWDataTransferManager.shared.deleteAfterTransfer = deleteAfterTransfer
        AWDataTransferManager.shared.transferData(sensors: sensors, completion: completion)
    }

    /// Transfer only sensor records that have not been transferred in a previous session.
    ///
    /// The highest record ID successfully transferred is stored in UserDefaults on the
    /// watch. Subsequent calls skip all records up to and including that ID, sending
    /// only new data. On the very first call (no stored bookmark), all records are sent.
    ///
    /// - Parameters:
    ///   - deleteAfterTransfer: When `true`, the transferred records are deleted from
    ///     the watch-side database after the transfers complete. Defaults to `false`.
    ///   - completion: Called on the main thread when all file transfers complete or
    ///     an error occurs.
    public func transferIncrementalData(deleteAfterTransfer: Bool = false,
                                        completion: ((Error?) -> Void)? = nil) {
        AWDataTransferManager.shared.transferMode = .incremental
        AWDataTransferManager.shared.deleteAfterTransfer = deleteAfterTransfer
        AWDataTransferManager.shared.transferData(sensors: sensors, completion: completion)
    }
}
