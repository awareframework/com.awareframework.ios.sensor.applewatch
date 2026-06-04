//
//  AWWCSessionManager.swift
//  com.awareframework.ios.sensor.applewatch
//
//  Created by Yuuki Nishiyama on 2025/07/10.
//

import WatchConnectivity
import com_awareframework_ios_core
import com_awareframework_ios_sensor_applewatch_shared

/** watch connection */
public class AWWCSessionManager: NSObject, WCSessionDelegate{
    
    public static let shared = AWWCSessionManager()
    private static let pairedDeviceIdKey = "com.aware.ios.sensor.core.key.paired_deviceid"
    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    public var sessionStateChangeHandler:((_ session: WCSession,
                                           _ activationState: WCSessionActivationState)->Void)?

    /// WatchConnectivity メッセージを受信したときに呼ばれるハンドラー。
    /// 外部センサー（AWUWBSensor 等）がトークン交換などを行うために使用する。
    public var messageHandler: ((_ message: [String: Any]) -> Void)?

    public var DEBUG = true
    private var lastMessageAt: Date?
    private var lastFileTransferAt: Date?
    private var lastError: String?
    
    public func getSettings(_ handler: (([String : Any]) -> Void)?){
        WCSession.default.sendMessage(["method":"get_settings"]) { settings in
            if let h = handler {
                h(settings)
            }
        }
    }
    
    public func getPairedDeviceId(_ handler: @escaping ((String?)->Void) ) {
        WCSession.default.sendMessage(["method":"get_device_id"]) { settings in
            self.lastMessageAt = Date()
            if let deviceId = settings["device_id"] as? String {
                handler(deviceId)
            }else{
                handler(nil)
            }
            
        } errorHandler: { error in
            self.lastError = error.localizedDescription
            handler(nil)
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
                pairedDeviceId: pairedDeviceId(),
                lastMessageAt: lastMessageAt,
                lastFileTransferAt: lastFileTransferAt,
                lastError: lastError
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
            pairedDeviceId: pairedDeviceId(),
            lastMessageAt: lastMessageAt,
            lastFileTransferAt: lastFileTransferAt,
            lastError: lastError
        )
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
        lastMessageAt = Date()
        lastError = error?.localizedDescription
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
            lastError = e.localizedDescription
            if self.DEBUG {
                print("\(#function): did not complete the file transfer -> \(fileTransfer.file.fileURL.lastPathComponent) \(e.localizedDescription)")
            }
        }else{
            lastFileTransferAt = Date()
            if self.DEBUG {
                print("\(#function): complete the file transfer & remove a local file -> \(fileTransfer.progress.fractionCompleted) \(fileTransfer.file.fileURL.lastPathComponent)")
            }
            /// NOTE: 本体からのレスポンスがあった時のみ削除
//            if (fileTransfer.progress.isFinished) {
//                removeSensorDataFile(fileTransfer.file.fileURL.lastPathComponent)
//            }
        }
    }
    
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        lastMessageAt = Date()
        if DEBUG { print("\(#function): \(message.debugDescription)") }
        messageHandler?(message)
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        lastMessageAt = Date()
        print("\(#function): \(message.debugDescription)")
        
        if let method = message["method"] as? String {
            if method == "manual_device_id_exchange" || method == "set_paired_device_id" {
                if let deviceId = message["device_id"] as? String, deviceId.isEmpty == false {
                    setPairedDeviceId(deviceId)
                }
                replyHandler([
                    "device_id": AwareUtils.getCommonDeviceId(),
                    "paired_device_id": pairedDeviceId() ?? "",
                ])
                return
            }
            
            if method == "get_device_id" {
                replyHandler(["device_id": AwareUtils.getCommonDeviceId()])
                return
            }
        }
        
        guard let eventName = message["event_name"] as? String,
              let fileName  = message["file_path"]  as? String else {
            replyHandler(["status": "unsupported"])
            return
        }
        
        if (eventName == "file_transfer_completion") {
            if (self.DEBUG) { print("[Remove Synced File]: ", fileName) }
//            removeSensorDataFile(fileName)
            replyHandler(["status": "ok"])
        } else {
            replyHandler(["status": "ignored"])
        }
    }
    
    private func pairedDeviceId() -> String? {
        UserDefaults.standard.string(forKey: Self.pairedDeviceIdKey)
    }
    
    private func setPairedDeviceId(_ deviceId: String) {
        UserDefaults.standard.set(deviceId, forKey: Self.pairedDeviceIdKey)
        UserDefaults.standard.synchronize()
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
