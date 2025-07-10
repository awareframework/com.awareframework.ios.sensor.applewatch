//
//  AudioManager.swift
//  MiQWatch Extension
//
//  Created by Yuuki Nishiyama on 2021/06/01.
//

import UIKit
import Foundation
import MediaPlayer
import AVFoundation
import WatchConnectivity
import UserNotifications
import SoundAnalysis

import com_awareframework_ios_sensor_applewatch_shared
import com_awareframework_ios_core



public struct AWDecibelLinePoint {
    public var date: Date
    public var value: Double
}

public struct AWAudioClassPoint{
    public var family: String
    public var date:Date
    public var confidence:Double
}


extension AWAudioSensor: SNResultsObserving {
    
    
    public func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        DispatchQueue.main.async {
            let now = Date()
            self.audioClasses.removeAll()
            for c in result.classifications {
                self.audioClasses.append(AWAudioClassPoint(family: c.identifier, date: now, confidence: c.confidence))
            }
            let maxKnownClassies = self.knownClassifications?.count ?? 0
            let topK = self.CONFIG.storeOnlyTopK ?? maxKnownClassies
            for audioClass in result.classifications.sorted(by: { a, b in
                return (a.confidence > b.confidence);
            })[..<topK] {
                /** ===== save audio label data ======  */
                let d = AWAudioLabelData(timestamp:Int64(now.timeIntervalSince1970 * 1000),
                                         audioLabel: audioClass.identifier,
                                            confidence: audioClass.confidence,
                                            label: self.CONFIG.label)
                
                if (self.CONFIG.debug) {
                    print(self.TAG, audioClass.identifier, audioClass.confidence)
                }
                
                if let sqliteEngine = self.audioLabelSensor?.dbEngine {
                    sqliteEngine.save(d.toDictionary())
                }
                /** ============================ */
            }
            if (self.CONFIG.debug) {
                print(self.TAG, "====================")
            }
        }
    }
    
}

final public class AWAudioSensor: AwareSensor, ObservableObject{

    private var audioEngine = AVAudioEngine()

    var endInterruptionHandler:(()->Void)?=nil
    var beginInterruptionHandler:(()->Void)?=nil

    var audioRecorder: AVAudioRecorder!
    var isReadySessionCategory = false
    
    // var lastBreakTimeAmbient = Date()
    var lastBreakTimeAudio = Date()
    var lastBreakTimeAudioClassifier = Date()
    var knownClassifications:[String]?

    @Published public var decibels = [AWDecibelLinePoint]()
    @Published public var audioClasses = [AWAudioClassPoint]()
    
    var streamAnalyzer : SNAudioStreamAnalyzer!
    var analysisQueue : DispatchQueue!
//    public var config = AWSensorConfig()
    var timer:Timer?
    private var isSuspended = false
    
    let TAG = "AWARE::AppleWatch:audio"

    
    public var audioLabelSensor:AWAudioLabelSensor?
    public var ambientNoiseSensor:AWAmbientNoiseSensor?
    
    public var CONFIG = AWAudioSensor.Config()
    
    /** configuration */
    public class Config:SensorConfig {
        public var onBus = 0;
        public var bufferSize:UInt32 = 8192;
        public var interval:Double?; // seconds
        
        public var audioRecordFormat = kAudioFormatMPEG4AAC; // kAudioFormatLinearPCM (非圧縮フォーマット)
        public var audioRecordSampleRate = 22050; // 44100,
        public var audioRecordQuality:AVAudioQuality = .medium;
        public var audioRecordNumberOfChannels = 1;
        
        public var audioBufferHandler:AVAudioNodeTapBlock?
        public var audioClassifierModel:MLModel?
        
        public var autoFileTransferInterval = 60 * 15 // 15 minutes
        
        public var activateAmbientNoiseSensor = false
        public var activateRawAudioSensor = false
        public var activateAudioClassificationSensor = false
        
        // public var storeOnlyFilterData = true
        public var storeOnlyTopK:Int?
        
        public override init(){
            super.init()
        }
        
        public override func set(config: Dictionary<String, Any>) {
            super.set(config: config)
        }
        
        public func apply(closure: (_ config: AWAudioSensor.Config ) -> Void) -> Self {
            closure(self)
            return self
        }
    }
    
    /** init operation */
    public init(_ config:AWAudioSensor.Config) {
        super.init()
        self.CONFIG = config
        self.initializeDbEngine(config: config)
        ambientNoiseSensor = AWAmbientNoiseSensor(config)
        audioLabelSensor = AWAudioLabelSensor(config)
        
        analysisQueue = DispatchQueue(label: "com.awareframework.watch.audio.AnalysisQueue")
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInterruption),
                                               name: AVAudioSession.interruptionNotification,
                                               object: AVAudioSession.sharedInstance())
    }
    
    deinit {
        audioEngine.inputNode.removeTap(onBus: self.CONFIG.onBus)
        self.audioEngine.reset()
        NotificationCenter.default.removeObserver(self,
                                                  name: AVAudioSession.interruptionNotification,
                                                  object: AVAudioSession.sharedInstance())
    }
    

    
    /** =========== start operation ================= */
    
    public override func start() {
        self.startSensor()
    }
    
    public override func stop(){
        self.stopAudioProcessing()
        self.stopAudioRecord()
    }
    
    public override func sync(force: Bool = false) {
        self.ambientNoiseSensor?.sync(force: force)
        self.audioLabelSensor?.sync(force: force)
    }
    
    
    /** ==== start operations === */
    
    private func startSensor(){
        if (self.CONFIG.debug){
            showAvailableInputs()
        }
        
        if(audioEngine.inputNode.inputFormat(forBus: self.CONFIG.onBus).channelCount == 0){
            setNotificationForSensorReboot()
            return
        }
        
        
        // Configure the audio session for the app.
        let audioSession = AVAudioSession.sharedInstance()
        audioSession.requestRecordPermission { granted in
            if granted {
                do {
                    if (!self.isReadySessionCategory) {
                        try audioSession.setCategory(.record,
                                                     mode: .default,
                                                     options: [])
                        try audioSession.setActive(true, options: .notifyOthersOnDeactivation) //.notifyOthersOnDeactivation)
                        self.isReadySessionCategory = true
                    }
                }catch{
                    print(error)
                }
                
                if (self.CONFIG.activateAmbientNoiseSensor || self.CONFIG.activateAudioClassificationSensor) {
                    self.startAudioProcessing(inputNode: self.audioEngine.inputNode)
                }

                if (self.CONFIG.activateRawAudioSensor){
                    let audioFile = self.createFileUrl(fileName: "audio_\(Int(Date().timeIntervalSince1970)).m4a")
                    self.startAudioRecord(audioFile: audioFile, inputNode: self.audioEngine.inputNode)
                }
                
            }
        }
    }
    
    private func startAudioProcessing(inputNode:AVAudioInputNode){
        
        let inputFormat = inputNode.inputFormat(forBus: self.CONFIG.onBus)

        streamAnalyzer = SNAudioStreamAnalyzer(format: inputFormat)
        do {
            if let model = self.CONFIG.audioClassifierModel {
                let request = try SNClassifySoundRequest(mlModel: model)
                self.knownClassifications = request.knownClassifications
                try streamAnalyzer.add(request, withObserver: self)
            }else{
                let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
                try streamAnalyzer.add(request, withObserver: self)
                self.knownClassifications = request.knownClassifications
            }
        }catch{
        }
        
        // <AVAudioFormat 0x15dc08c0:  1 ch,  48000 Hz, Float32>
        inputNode.installTap(onBus: self.CONFIG.onBus,
                             bufferSize: self.CONFIG.bufferSize,
                             format: inputFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            
            if let tapBlock = self.CONFIG.audioBufferHandler {
                tapBlock(buffer, when)
            }
            
            if self.CONFIG.activateAudioClassificationSensor {
                self.analysisQueue.async {
                    self.streamAnalyzer.analyze(buffer, atAudioFramePosition: when.sampleTime)
                }
            }
            
            if self.CONFIG.activateAmbientNoiseSensor {
                if let audioData = buffer.floatChannelData?[0] {
                    let rms = SignalProcessing.rms(data: audioData, frameLength: UInt(buffer.frameLength))
                    let db = SignalProcessing.db(from: rms)
                    
                    DispatchQueue.main.async {
                        if (db.isInfinite) {
                            if (self.CONFIG.debug == true) { print("AWARE::AppleWatch [AWAudioSensor] dB is infinite") }
                            return
                        }
             
                        /** ===  save ambient noise data ===  */
                        let now = Date()
                        let d = AWAmbientNoiseData(timestamp: Int64(now.timeIntervalSince1970 * 1000),
                                                   db: Double(db),
                                                   label: self.CONFIG.label)
                        
                        if let sqliteEngine = self.ambientNoiseSensor?.dbEngine {
                            sqliteEngine.save(d.toDictionary())
                        }
                        
                        if (self.CONFIG.debug) {
                            print(self.TAG, now, db)
                        }
                        
                        /** ==========================  */
                        
                        self.decibels.append(AWDecibelLinePoint(date: now , value: Double(db)))
                        if (self.decibels.count > 100) {
                            self.decibels.removeFirst()
                        }
                        
                    }
                }
            }
        }

//        audioEngine.connect(inputNode, to: delay, format:delay.inputFormat(forBus: 0))
//        audioEngine.connect(delay, to: outputNode, format:nil)
  
        audioEngine.prepare()

        do {
            try audioEngine.start()
            if CONFIG.debug {
                showAudioRoute()
            }
        }catch {
            print(error)
        }
    }
    
    
    private func startAudioRecord(audioFile:URL, inputNode:AVAudioInputNode){
        let recordSetting: [String: Any] = [
            AVSampleRateKey: NSNumber(value: self.CONFIG.audioRecordSampleRate),
            AVFormatIDKey: NSNumber(value: self.CONFIG.audioRecordFormat),
            AVNumberOfChannelsKey: NSNumber(value: self.CONFIG.audioRecordNumberOfChannels),
            AVEncoderAudioQualityKey: NSNumber(value: self.CONFIG.audioRecordQuality.rawValue)
        ]

        do {
            self.audioRecorder = try AVAudioRecorder(url: audioFile, settings: recordSetting)
            self.audioRecorder.delegate = self
            self.audioRecorder.record()
            self.audioRecorder.isMeteringEnabled = true
        } catch  {
            print(error)
        }
        
        if (self.CONFIG.debug) {
            print("\(#function): \(Thread.isMainThread)")
        }
        
        self.timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(self.CONFIG.autoFileTransferInterval),
                             repeats: false) { timer in
            self.stopAudioRecord()
            
            if self.timer == nil {
                let audioFile = self.createFileUrl(fileName: "audio_\(Int(Date().timeIntervalSince1970)).m4a")
                self.startAudioRecord(audioFile: audioFile, inputNode: self.audioEngine.inputNode)
                
            }
        }
    }
    
    
    /**  =============== stop operations  =============== */

    
    private func stopAudioProcessing(){
        // self.removeRemoteCommandEvents()
        self.audioEngine.stop()
        self.audioEngine.disconnectNodeOutput(self.audioEngine.inputNode)
        self.audioEngine.inputNode.removeTap(onBus: self.CONFIG.onBus)
        self.audioEngine.reset()
    }
    
    private func stopAudioRecord(){
        self.audioRecorder?.stop()
        self.timer?.invalidate()
        self.timer = nil
    }
    
    

    /** ===============  Utils ===============  */
    private func createFileUrl(fileName:String) -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let docsDirect = paths[0]
        let newFileUrl = docsDirect.appendingPathComponent(fileName)
        return newFileUrl
    }

    private func showAudioRoute(){
        let audioSession = AVAudioSession.sharedInstance()
        print("-----")
        print(audioSession.currentRoute)
        print(audioSession.routeSharingPolicy.rawValue)
        print("-----")
    }
    
    private func showAvailableInputs(){
        let audioSession = AVAudioSession.sharedInstance()
        if let inputs = audioSession.availableInputs {
            for input in inputs {
                // <AVAudioSessionPortDescription: 0x145d9500, type = MicrophoneBuiltIn;
                // name = Apple Watch Microphone; UID = Built-In Microphone; selectedDataSource = (null)>
                print(input)
            }
        }
    }
    
    private func setNotificationForSensorReboot(){
        print("Not enough available inputs!")
        audioEngine.reset()
        
        let content = UNMutableNotificationContent()
        content.title = "Error: Please Restart!"
        content.subtitle = "An audio session is crashed by an interrupt event (maybe Siri). Please restart the sensors manually."
        content.sound = .defaultCritical
        content.categoryIdentifier = "awareWatch"
        let category = UNNotificationCategory(identifier: "awareWatch", actions: [], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { (error) in
            if let error = error{
                print(error.localizedDescription)
            }else{
                print("scheduled successfully")
            }
        }
    }
    
    @objc func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            if let handler = beginInterruptionHandler {
                handler()
            }
            // 割り込みが開始された
            print("Interruption began")
            if !isSuspended {
                isSuspended = true
                self.stop()
            }
            // 必要に応じてここで録音を一時停止など
        case .ended:
            if let handler = endInterruptionHandler {
                handler()
            }
            // 割り込みが終了した
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // 割り込み後に再開可能
                    print("Interruption ended - should resume")
                    // 録音を再開するなど
                    if isSuspended {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.start()
                        }
                        isSuspended = false
                    }

                } else {
                    print("Interruption ended - should not resume")
                }
            }
        @unknown default:
            break
        }
    }
}


extension AWAudioSensor:AVAudioRecorderDelegate{
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if (self.CONFIG.debug) {
            print("\(#function): \(recorder.url.lastPathComponent) \(flag) ")
        }
    }
}
