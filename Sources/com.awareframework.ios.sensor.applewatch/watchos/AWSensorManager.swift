import HealthKit
import CoreML
import UserNotifications
import WatchConnectivity
import AVFoundation

import com_awareframework_ios_core

public class AWSensorManager: NSObject {
    
    public static let shared = AWSensorManager()
    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    public var sensors:[AwareSensor] = []
    
    let healthStore:HKHealthStore = HKHealthStore()
    var session : HKWorkoutSession?
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
    
    public func start(useWorkoutSession: Bool = false, _ handler:(()->Void)?){
        DispatchQueue.main.async {
            for s in self.sensors {
                s.start()
            }
            if (useWorkoutSession) {
                self.startWorkout()
            }
            WCSession.default.sendMessage(["status":1], replyHandler: nil)
            handler?()
        }
    }
    
    public func stop(_ handler:(()->Void)?){
        DispatchQueue.main.async {
            for s in self.sensors {
                s.stop()
            }
            self.stopWorkout()
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
    
    public func getSettings(_ handler: (([String : Any]) -> Void)?){
        WCSession.default.sendMessage(["method":"get_settings"]) { settings in
            if let h = handler {
                h(settings)
            }
        }
    }
}

/** workout sessions */
extension AWSensorManager: HKWorkoutSessionDelegate{

    func startWorkout() {
        #if os(iOS)

        #elseif os(watchOS)
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
            fatalError("Unable to create the workout session!")
        }
        #endif
    }
    
    
    func stopWorkout(){
        if let workout = self.session {
            workout.end()
        }
        self.session = nil
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

/** watch connection */
extension AWSensorManager: WCSessionDelegate{
    
    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    public func sessionDidDeactivate(_ session: WCSession) {
        
    }
    #elseif os(watchOS)
    #endif
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if (debug) {
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
            if debug {
                print("\(#function): did not complete the file transfer -> \(fileTransfer.file.fileURL.lastPathComponent) \(e.localizedDescription)")
            }
        }else{
            if debug {
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
            if (debug) { print("[Remove Synced File]: ", fileName) }
//            removeSensorDataFile(fileName)
        }
    }
    
}

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
            if let hrSensor = s as? AWHealthKitSensor {
                hrSensor.initHealthKit { success, error in
                    completion(success, error)
                }
            }
            #endif
        }
    }
}

