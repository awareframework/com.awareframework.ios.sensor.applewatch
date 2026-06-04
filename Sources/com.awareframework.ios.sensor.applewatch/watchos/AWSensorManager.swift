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
    }

    public var sensors:[AwareSensor] = []
    
    let healthStore:HKHealthStore = HKHealthStore()
    #if os(watchOS)
    var session : HKWorkoutSession?
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
}

/** workout sessions */
#if os(watchOS)
extension AWSensorManager: HKWorkoutSessionDelegate{

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
            fatalError("Unable to create the workout session!")
        }
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
#else
extension AWSensorManager {
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
            if let hrSensor = s as? AWHealthKitSensor {
                hrSensor.initHealthKit { success, error in
                    completion(success, error)
                }
            }
            #endif
        }
    }
}

extension AWSensorManager {

    /// Transfer all locally stored sensor data to the paired iPhone using
    /// `AWDataTransferManager`.  Data is JSON-encoded, zlib-compressed, and
    /// split into chunks before being handed to WatchConnectivity.
    ///
    /// - Parameters:
    ///   - completion: Called on the main thread when all file transfers
    ///     complete or an error occurs.
    public func transferAllData(completion: ((Error?) -> Void)? = nil) {
        AWDataTransferManager.shared.transferData(sensors: sensors, completion: completion)
    }
}
