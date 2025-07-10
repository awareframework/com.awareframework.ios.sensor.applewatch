//
//  AWWCSessionManager.swift
//  com.awareframework.ios.sensor.applewatch
//
//  Created by Yuuki Nishiyama on 2025/07/10.
//

import WatchConnectivity

/** watch connection */
public class AWWCSessionManager: NSObject, WCSessionDelegate{
    
    public static let shared = AWWCSessionManager()
    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    public var sessionStateChangeHandler:((_ session: WCSession,
                                           _ activationState: WCSessionActivationState)->Void)?
    
    public var DEBUG = true
    
    public func getSettings(_ handler: (([String : Any]) -> Void)?){
        WCSession.default.sendMessage(["method":"get_settings"]) { settings in
            if let h = handler {
                h(settings)
            }
        }
    }
    
    public func getPairedDeviceId(_ handler: @escaping ((String?)->Void) ) {
        WCSession.default.sendMessage(["method":"get_device_id"]) { settings in
            if let deviceId = settings["device_id"] as? String {
                handler(deviceId)
            }else{
                handler(nil)
            }
            
        }
    }
    
    
    
    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    public func sessionDidDeactivate(_ session: WCSession) {
        
    }
    #elseif os(watchOS)
    
    #endif
    
    public func session(_ session: WCSession,
                        activationDidCompleteWith activationState: WCSessionActivationState,
                        error: Error?) {
        if let handler = self.sessionStateChangeHandler {
            handler(session, activationState)
        }
        if (self.DEBUG) {
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
    
    public func session(_ session: WCSession,
                        didFinish fileTransfer: WCSessionFileTransfer,
                        error: Error?) {
        
        if let e = error {
            if self.DEBUG {
                print("\(#function): did not complete the file transfer -> \(fileTransfer.file.fileURL.lastPathComponent) \(e.localizedDescription)")
            }
        }else{
            if self.DEBUG {
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
              let fileName  = message["file_path"]  as? String else {
            return
        }
        
        if (eventName == "file_transfer_completion") {
            if (self.DEBUG) { print("[Remove Synced File]: ", fileName) }
//            removeSensorDataFile(fileName)
        }
    }
    
}
