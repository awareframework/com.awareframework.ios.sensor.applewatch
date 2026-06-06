//
//  ViewController.swift
//  com.awareframework.ios.sensor.applewatch
//
//  Created by 1227623 on 12/16/2022.
//  Copyright (c) 2022 1227623. All rights reserved.
//

import UIKit
import WatchConnectivity
import com_awareframework_ios_sensor_core
import com_awareframework_ios_sensor_applewatch

class ViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    
    var lastUpdateMotion = Date()
    var lastUpdateHR = Date()
    var lastUpdateAudio = Date()
    var lastUpdateAudioFile = Date()
    
    func updateView(_ line:String){
        self.textView.text = line + "\n" + self.textView.text
//
//        self.textView.text
//        self.textView.text =
//        """
//        heatrate:\t\(lastUpdateHR)
//        audio:\t\t\(lastUpdateAudio)
//        audiofile:\t\(lastUpdateAudioFile)
//        motion:\t\t\(lastUpdateMotion)
//        """
    }
    
    @IBAction func didPushExportButton(_ sender: Any) {
       
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        if WCSession.isSupported() {
            WCSession.default.activate()
        }
        
        for sensor in SensorManager.shared.sensors {
            if let appleWatchSensor = sensor as? AppleWatchSensor {
                appleWatchSensor.CONFIG.sensorObserver = self

            }
        }

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}



extension ViewController:AppleWatchObserver {
    

    func onHeartRateChanged(data: Dictionary<String, Any>) {
        DispatchQueue.main.async {
            self.lastUpdateHR = Date()
//            self.updateView()
        }
    }
    
    func onAudioChanged(data:Dictionary<String, Any>) {
        DispatchQueue.main.async {
            self.lastUpdateAudio = Date()
//            self.updateView()
        }
    }
    
    func onMotionChanged(data:Dictionary<String, Any>) {
        DispatchQueue.main.async {
            self.lastUpdateMotion = Date()
//            self.updateView()
        }
    }
    
    func onAudioFileReceived(data: URL) {
        DispatchQueue.main.async {
            self.lastUpdateAudioFile = Date()
//            self.updateView()
        }
    }
    
    func didReceive(file: URL) {
        print(file.lastPathComponent)
        DispatchQueue.main.async {
            /// DateFomatterクラスのインスタンス生成
            let dateFormatter = DateFormatter()
            /// カレンダー、ロケール、タイムゾーンの設定（未指定時は端末の設定が採用される）
            dateFormatter.calendar = Calendar(identifier: .gregorian)
            dateFormatter.locale = Locale(identifier: "ja_JP")
            dateFormatter.timeZone = TimeZone(identifier:  "Asia/Tokyo")
            /// 変換フォーマット定義（未設定の場合は自動フォーマットが採用される）
            dateFormatter.dateFormat = "yyyy/M/d H:m:s"
            
            /// データ変換（Date→テキスト）
            let dateString = dateFormatter.string(from: Date())
            self.updateView("\(dateString) -> \(file.lastPathComponent)")
        }
    }
}
