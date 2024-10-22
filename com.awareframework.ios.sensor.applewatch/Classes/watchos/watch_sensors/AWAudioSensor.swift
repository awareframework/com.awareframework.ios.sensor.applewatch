//
//  AudioManager.swift
//  MiQWatch Extension
//
//  Created by Yuuki Nishiyama on 2021/06/01.
//

import UIKit
import Foundation
import MediaPlayer
import Accelerate
import AVFoundation
import WatchConnectivity
import UserNotifications
import SoundAnalysis

extension AWAudioSensor:AVAudioRecorderDelegate{
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if (self.config.debug) {
            print("\(#function): \(recorder.url.lastPathComponent) \(flag) ")
        }
        if (flag) {
            fileTransferManager.transferFile(fileURL: recorder.url, debug: self.config.debug)
        }
    }
}

public struct AWDecibelLinePoint {
    public var date: Date
    public var value: Double
}

public struct AWAudioClassPoint{
    public var family: String
    public var date:Date
    public var confidence:Double
}


public class AWAudioSensorConfig {
    public var onBus = 0;
    public var bufferSize:UInt32 = 8192;
    public var interval:Double?; // seconds
    
    public var audioRecordFormat = kAudioFormatMPEG4AAC; // kAudioFormatLinearPCM (非圧縮フォーマット)
    public var audioRecordSampleRate = 22050; // 44100,
    public var audioRecordQuality:AVAudioQuality = .medium;
    public var audioRecordNumberOfChannels = 1;
    
    public var storeOnlyFilterData = false
//    public var storeOnlyTargetAudioClass:[String]?
    public var storeOnlyTopK:Int?
//    public var storeOnlyAboveCertenConfidenceLevel:Double?
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
            if self.config.audioSensorConfig.storeOnlyFilterData {
                let maxKnownClassies = self.knownClassifications?.count ?? 0
                let topK = self.config.audioSensorConfig.storeOnlyTopK ?? maxKnownClassies
                for audioClass in result.classifications.sorted(by: { a, b in
                    return (a.confidence > b.confidence);
                })[..<topK] {
                    print(audioClass.identifier, audioClass.confidence)
                    self.audioClassifierSimpleData?.update(identifier: audioClass.identifier, confidence: audioClass.confidence )
                }
                print("--------")
            } else {
                self.audioClassifierData?.update(result.classifications)
            }
            
            let gap = now.timeIntervalSince(self.lastBreakTimeAudioClassifier)
            if (gap > Double(self.config.autoFileTransferInterval)){
                
                if self.config.audioSensorConfig.storeOnlyFilterData {
                    // transfer data and create new data object
                    if let audioClassifierSimpleData = self.audioClassifierSimpleData {
                        audioClassifierSimpleData.closeFileHandler()
                        self.fileTransferManager.transferFile(fileURL: audioClassifierSimpleData.filePath,
                                                              debug: self.config.debug)
                    }
                    self.audioClassifierSimpleData?.openFileHandler()
                }else{
                    // transfer data and create new data object
                    if let audioClassifierData = self.audioClassifierData {
                        audioClassifierData.closeFileHandler()
                        self.fileTransferManager.transferFile(fileURL: audioClassifierData.filePath,
                                                              debug: self.config.debug)
                    }
                    if let uwKnownClassifications = self.knownClassifications {
                        self.audioClassifierData = AWAudioClassifierSensorData(knownClassifications: uwKnownClassifications)
                    }
                    self.audioClassifierData?.openFileHandler()
                }
                
                
                
                self.lastBreakTimeAudioClassifier = now
                
            }
        }
    }
}

final public class AWAudioSensor:NSObject, ObservableObject{

    private var audioEngine = AVAudioEngine()
    // private var audioFile:AVAudioFile?
    // private var k44mixer = AVAudioMixerNode()

    var endInterruptionHandler:(()->Void)?=nil
    var beginInterruptionHandler:(()->Void)?=nil

    var audioRecorder: AVAudioRecorder!
    var isReadySessionCategory = false
    
    var lastBreakTimeAmbient = Date()
    var lastBreakTimeAudio = Date()
    var lastBreakTimeAudioClassifier = Date()
    var sensorData:AWAudioSensorData?
    var audioClassifierData:AWAudioClassifierSensorData?
    var audioClassifierSimpleData:AWAudioClassifierSimpleSensorData?
    var knownClassifications:[String]?

    @Published public var decibels = [AWDecibelLinePoint]()
    @Published public var audioClasses = [AWAudioClassPoint]()
    
    let fileTransferManager = FileTransferManager()
    
    var streamAnalyzer : SNAudioStreamAnalyzer!
    var analysisQueue : DispatchQueue!
    
    public var config = AWSensorConfig()
    
    private var isSuspended = false

    public override init() {
        super.init()
        analysisQueue = DispatchQueue(label: "com.awareframework.watch.audio.AnalysisQueue")
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
    }
    
    deinit {
        audioEngine.inputNode.removeTap(onBus: self.config.audioSensorConfig.onBus)
        self.audioEngine.reset()
        
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification,
                                                  object: AVAudioSession.sharedInstance())
    }
    
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
    
    public func start(_ config:AWSensorConfig){
        
        self.config = config
        
        if(audioEngine.inputNode.inputFormat(forBus: self.config.audioSensorConfig.onBus).channelCount == 0){
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
                
                if (self.config.activateAmbientNoiseSensor || self.config.activateAudioClassificationSensor) {
                    self.startAudioProcessing(inputNode: self.audioEngine.inputNode)
                }

                if (self.config.activateRawAudioSensor){
                    let audioFile = self.createFileUrl(fileName: "audio_\(Int(Date().timeIntervalSince1970)).m4a")
                    self.startAudioRecord(audioFile: audioFile, inputNode: self.audioEngine.inputNode)
                }
                
            }
        }
    }
    
    private func startAudioProcessing(inputNode:AVAudioInputNode){
        
        let inputFormat = inputNode.inputFormat(forBus: self.config.audioSensorConfig.onBus)

        do {
            streamAnalyzer = SNAudioStreamAnalyzer(format: inputFormat)
            if let model = self.config.audioClassifierModel {
                let request = try SNClassifySoundRequest(mlModel: model)
                self.knownClassifications = request.knownClassifications
                try streamAnalyzer.add(request, withObserver: self)
            }else{
                let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
                try streamAnalyzer.add(request, withObserver: self)
                self.knownClassifications = request.knownClassifications
            }
        
            if config.audioSensorConfig.storeOnlyFilterData {
                // filter が入る場合の処理
                audioClassifierSimpleData = AWAudioClassifierSimpleSensorData()
                audioClassifierSimpleData?.openFileHandler()
            }else{
                audioClassifierData =  AWAudioClassifierSensorData(knownClassifications: self.knownClassifications!)
                audioClassifierData?.openFileHandler()
            }
        } catch {
            print("Unable to prepare request: \(error.localizedDescription)")
            return
        }
        
        // <AVAudioFormat 0x15dc08c0:  1 ch,  48000 Hz, Float32>
        inputNode.installTap(onBus: self.config.audioSensorConfig.onBus,
                             bufferSize: self.config.audioSensorConfig.bufferSize,
                             format: inputFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            
            if let tapBlock = self.config.audioBufferHandler {
                tapBlock(buffer, when)
            }
            
            if self.config.activateAudioClassificationSensor {
                self.analysisQueue.async {
                    self.streamAnalyzer.analyze(buffer, atAudioFramePosition: when.sampleTime)
                }
            }
            
            if self.config.activateAmbientNoiseSensor {
                if let audioData = buffer.floatChannelData?[0] {
                    let rms = SignalProcessing.rms(data: audioData, frameLength: UInt(buffer.frameLength))
                    let db = SignalProcessing.db(from: rms)
                    
                    DispatchQueue.main.async {
                        self.sensorData?.update(db: Double(db))
                        
                        let now = Date()
                        let gap = now.timeIntervalSince(self.lastBreakTimeAmbient)
                        if (gap > Double(self.config.autoFileTransferInterval)){
                            
                            if let sensorData = self.sensorData {
                                sensorData.closeFileHandler()
                                self.fileTransferManager.transferFile(fileURL: sensorData.filePath, debug: self.config.debug)
                            }
                            
                            self.sensorData = AWAudioSensorData()
                            self.sensorData?.openFileHandler()
                            self.lastBreakTimeAmbient = now
                        }
                        
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
            if config.debug {
                showAudioRoute()
            }
        }catch {
            print(error)
        }
    }
    
    var timer:Timer?
    
    private func startAudioRecord(audioFile:URL, inputNode:AVAudioInputNode){
        let recordSetting: [String: Any] = [
            AVSampleRateKey: NSNumber(value: self.config.audioSensorConfig.audioRecordSampleRate),
            AVFormatIDKey: NSNumber(value: self.config.audioSensorConfig.audioRecordFormat),
            AVNumberOfChannelsKey: NSNumber(value: self.config.audioSensorConfig.audioRecordNumberOfChannels),
            AVEncoderAudioQualityKey: NSNumber(value: self.config.audioSensorConfig.audioRecordQuality.rawValue)
        ]

        do {
            self.audioRecorder = try AVAudioRecorder(url: audioFile, settings: recordSetting)
            self.audioRecorder.delegate = self
            self.audioRecorder.record()
            self.audioRecorder.isMeteringEnabled = true
        } catch  {
            print(error)
        }
        
        if (self.config.debug) {
            print("\(#function): \(Thread.isMainThread)")
        }
        self.timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(self.config.autoFileTransferInterval),
                             repeats: false) { timer in
            self.stopAudioRecord()
            
            if self.timer == nil {
                let audioFile = self.createFileUrl(fileName: "audio_\(Int(Date().timeIntervalSince1970)).m4a")
                self.startAudioRecord(audioFile: audioFile, inputNode: self.audioEngine.inputNode)
                
            }
        }
    }
    


    public func stop(){
        self.stopAudioProcessing()
        self.stopAudioRecord()
    }
    
    private func stopAudioProcessing(){
        //        self.removeRemoteCommandEvents()
        self.audioEngine.stop()
        self.audioEngine.disconnectNodeOutput(self.audioEngine.inputNode)
        self.audioEngine.inputNode.removeTap(onBus: self.config.audioSensorConfig.onBus)
        self.audioEngine.reset()
            // self.audioEngine = nil
        self.sensorData?.closeFileHandler()
        if self.config.activateAmbientNoiseSensor {
            if let sensorData = self.sensorData {
                fileTransferManager.transferFile(fileURL: sensorData.filePath, debug: self.config.debug)
            }
        }
        
        self.audioClassifierData?.closeFileHandler()
        self.audioClassifierSimpleData?.closeFileHandler()
        
        if self.config.activateAudioClassificationSensor {
            if config.audioSensorConfig.storeOnlyFilterData {
                // simaple data
                if let audioClassifierSimpleData = self.audioClassifierSimpleData {
                    fileTransferManager.transferFile(fileURL: audioClassifierSimpleData.filePath, debug: self.config.debug)
                }
            }else{
                // all data
                if let audioClassifierData = self.audioClassifierData {
                    fileTransferManager.transferFile(fileURL: audioClassifierData.filePath, debug: self.config.debug)
                }
            }

        }
    }
    
    private func stopAudioRecord(){
        self.audioRecorder?.stop()
        self.timer?.invalidate()
        self.timer = nil
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
                            self.start(self.config)
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


final public class AWAudioSensorData:AWSensorData {
    
    var db:Double = 0.0
    
    init() {
        super.init("ambient", header: ["timestamp", "db", "label"])
    }
    
    func update(db:Double, label:String = ""){
        self.db = db
        
        var values:[String] = []
        
        // set timestamp
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        values.append("\(now)")
        values.append("\(db)")
        values.append(label)
        
        self.save(values)
    }
}


final public class AWAudioClassifierSensorData:AWSensorData {
    
    var knownClassifications:[String]
    var confidences:[SNClassification]?
    
    init(knownClassifications:[String]) {
        self.knownClassifications = knownClassifications
        self.knownClassifications.sort{ $0 < $1 }
        self.knownClassifications.insert("timestamp", at: 0)
        print(self.knownClassifications)
        super.init("audio-classifier", header: self.knownClassifications)
    }
    
    func update(_ confidences:[SNClassification]){
        // 文字列でソートしてデータを追加
        self.confidences = confidences.sorted{$0.identifier < $1.identifier}
        
        var values:[String] = []
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        values.append("\(now)")
        for snc in self.confidences! {
            values.append("\(snc.confidence)")
        }
        self.save(values)
    }
}

final public class AWAudioClassifierSimpleSensorData:AWSensorData {
    
    var identifier:String = ""
    var confidence:Double = 0.0
    
    init() {
        super.init("audio-classifier-simple", header: ["timestamp", "identifier", "confidence"])
    }
    
    func update(identifier:String = "", confidence:Double=0.0){
        self.identifier = identifier
        self.confidence = confidence
        
        var values:[String] = []
        
        // set timestamp
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        values.append("\(now)")
        values.append("\(identifier)")
        values.append("\(confidence)")
        
        self.save(values)
    }
}

//extension AWAudioSensor {
//    // MARK: Remote Command Event
//    func addRemoteCommandEvents() {
//         let commandCenter = MPRemoteCommandCenter.shared()
//         pauseHandler = commandCenter.pauseCommand.addTarget(handler: { [unowned self] commandEvent -> MPRemoteCommandHandlerStatus in
//            self.remotePause(commandEvent)
//            return MPRemoteCommandHandlerStatus.success
//        })
//
//    }
//
//     func removeRemoteCommandEvents(){
//         let commandCenter = MPRemoteCommandCenter.shared()
//         if let handler = self.pauseHandler {
//             commandCenter.pauseCommand.removeTarget(handler)
//         }
//     }
//
//    func remotePause(_ event: MPRemoteCommandEvent) {
//     print(#function)
////     if let handler = self.earphoneEventHandler {
////         handler()
////     }
//    }
//}


//https://betterprogramming.pub/audio-visualization-in-swift-using-metal-accelerate-part-1-390965c095d7

class SignalProcessing {

//    https://pebble8888.hatenablog.com/entry/2014/06/28/010205
//    https://macasakr.sakura.ne.jp/decibel4.html
    static func rms(data: UnsafeMutablePointer<Float>, frameLength: UInt) -> Float {
        var val : Float = 0
        vDSP_rmsqv(data, 1, &val, frameLength) // 要素の２乗の合計をNで割り平方根を取る
        return val
    }

    static func db(from rms:Float, base:Float=1) -> Float {
        /// 音圧レベルとは、音による気圧の差をデシベルで表示したものです。
        /// この場合、20μPaの音圧（気圧差）を基準値P0（0dB）として、以下の式で求められます。
        /// 音圧レベルLp=10log(P/P0)m2=20log(P/P0)
        return 20*log10f(rms/base)
    }

//    static func fft(data: UnsafeMutablePointer<Float>, setup: OpaquePointer) -> [Float] {
//        //output setup
//        var realIn = [Float](repeating: 0, count: 1024)
//        var imagIn = [Float](repeating: 0, count: 1024)
//        var realOut = [Float](repeating: 0, count: 1024)
//        var imagOut = [Float](repeating: 0, count: 1024)
//
//        //fill in real input part with audio samples
//        for i in 0...1023 {
//            realIn[i] = data[i]
//        }
//
//
//        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)
//        //our results are now inside realOut and imagOut
//
//
//        //package it inside a complex vector representation used in the vDSP framework
//        var complex = DSPSplitComplex(realp: &realOut, imagp: &imagOut)
//
//        //setup magnitude output
//        var magnitudes = [Float](repeating: 0, count: 512)
//
//        //calculate magnitude results
//        vDSP_zvabs(&complex, 1, &magnitudes, 1, 512)
//
//        return magnitudes;
//    }

    /// - Parameter buffer: Audio data in PCM format
    static func fft(_ buffer: AVAudioPCMBuffer) -> [Float] {

        let size: Int = Int(buffer.frameLength)

        /// Set up the transform
        let log2n = UInt(round(log2f(Float(size))))
        let bufferSize = Int(1 << log2n)

        /// Sampling rate / 2
        let inputCount = bufferSize / 2

        /// FFT weights arrays are created by calling vDSP_create_fftsetup (single-precision) or vDSP_create_fftsetupD (double-precision). Before calling a function that processes in the frequency domain
        let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))

        /// Create the complex split value to hold the output of the transform
        var realp = [Float](repeating: 0, count: inputCount)
        var imagp = [Float](repeating: 0, count: inputCount)
        var output = DSPSplitComplex(realp: &realp, imagp: &imagp)


        var transferBuffer = [Float](repeating: 0, count: bufferSize)
        vDSP_hann_window(&transferBuffer, vDSP_Length(bufferSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul((buffer.floatChannelData?.pointee)!, 1, transferBuffer,
                  1, &transferBuffer, 1, vDSP_Length(bufferSize))

        let temp = UnsafePointer<Float>(transferBuffer)

        temp.withMemoryRebound(to: DSPComplex.self, capacity: transferBuffer.count) { (typeConvertedTransferBuffer) -> Void in
            vDSP_ctoz(typeConvertedTransferBuffer, 2, &output, 1, vDSP_Length(inputCount))
        }
        /// Do the fast Fournier forward transform
        vDSP_fft_zrip(fftSetup!, &output, 1, log2n, Int32(FFT_FORWARD))

        /// Convert the complex output to magnitude
        var magnitudes = [Float](repeating: 0.0, count: inputCount)
        vDSP_zvmags(&output, 1, &magnitudes, 1, vDSP_Length(inputCount))

        var normalizedMagnitudes = [Float](repeating: 0.0, count: inputCount)
        vDSP_vsmul(sqrtq(magnitudes), 1, [2.0/Float(inputCount)],
                   &normalizedMagnitudes, 1, vDSP_Length(inputCount))

//        print("Normalized magnitudes: \(magnitudes)")

        /// Release the setup
         vDSP_destroy_fftsetup(fftSetup)

        return normalizedMagnitudes

    }

    static func sqrtq(_ x: [Float]) -> [Float] {
        var results = [Float](repeating: 0.0, count: x.count)
        vvsqrtf(&results, x, [Int32(x.count)])

        return results
    }

}

