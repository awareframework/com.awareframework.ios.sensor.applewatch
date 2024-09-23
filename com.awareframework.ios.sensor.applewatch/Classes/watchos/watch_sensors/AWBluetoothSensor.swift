//
//  AWBluetoothSensor.swift
//  com.awareframework.ios.sensor.applewatch-watchOS
//
//  Created by Yuuki Nishiyama on 2023/06/07.
//

import Foundation
import CoreBluetooth

public class AWBluetoothSensor: NSObject, ObservableObject {
    
    var centralManager:CBCentralManager?
//    var peripheralManager:CBPeripheralManager?
    
    var sensorDataBluetooth:AWBluetoothSensorData?

//    @Published public var bluetoothDevices = [AWHeadingPoint]()
    
    var isRunning = false
    
    var lastBreakTime = Date()
    var timer:Timer? = nil
    
//    var scanInterval = 60
    var scanTimer:Timer? = nil
    
//    var rebootInterval = 5
//    var rebootTimer:Timer? = nil
    
    let fileTransferManager = FileTransferManager()
    public var config = AWSensorConfig()
    
    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
//        self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func start(_ config:AWSensorConfig){
        self.config = config
        if (!isRunning) {
            isRunning = true
            startBluetoothScan()
        }
    }
    
    func stop(){
        if(isRunning) {
            isRunning = false
            self.stopBluetoothScan()
        }
    }
    
    @objc func startBluetoothScan(){
        if self.config.debug {
            print("スキャン開始", Thread.isMainThread)
        }
        // タイマーを設定する
        sensorDataBluetooth = AWBluetoothSensorData()
        sensorDataBluetooth?.openFileHandler()
        self.scanTimer = Timer.scheduledTimer(timeInterval: TimeInterval(self.config.autoFileTransferInterval),
                                              target: self,
                                              selector: #selector(self.stopBluetoothScan),
                                              userInfo: nil,
                                              repeats: false)
        // 機器を検出
         if self.centralManager?.isScanning == false {
             self.centralManager?.scanForPeripherals(withServices: nil, options: nil)
         }
    }
    
    /// スキャン停止
    @objc func stopBluetoothScan() {
        if self.config.debug {
            print("スキャン停止", Thread.isMainThread)
        }
        self.centralManager?.stopScan()
        // Timerを削除
        self.scanTimer?.invalidate()
        self.scanTimer = nil
        
//        self.rebootTimer?.invalidate()
//        self.rebootTimer = nil
        
        // transfer file
        if let sensorData = sensorDataBluetooth {
            sensorData.closeFileHandler()
            fileTransferManager.transferFile(fileURL: sensorData.filePath, debug: self.config.debug)
        }
        
        if (isRunning) {
            self.startBluetoothScan()
//            self.rebootTimer =  Timer.scheduledTimer(timeInterval: TimeInterval(self.rebootInterval),
//                                                     target: self,
//                                                     selector: #selector(self.startBluetoothScan),
//                                                     userInfo: nil,
//                                                     repeats: false)
        }
    }
    
}


extension AWBluetoothSensor: CBCentralManagerDelegate {

    /// Bluetoothのステータスを取得する(CBCentralManagerの状態が変わる度に呼び出される)
    ///
    /// - Parameter central: CBCentralManager
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOff:
            print("Bluetooth PoweredOff")
            break
        case .poweredOn:
            print("Bluetooth poweredOn")
            break
        case .resetting:
            print("Bluetooth resetting")
            break
        case .unauthorized:
            print("Bluetooth unauthorized")
            break
        case .unknown:
            print("Bluetooth unknown")
            break
        case .unsupported:
            print("Bluetooth unsupported")
            break
        }
    }

    /// スキャン結果取得
    ///
    /// - Parameters:
    ///   - central: CBCentralManager
    ///   - peripheral: CBPeripheral
    ///   - advertisementData: アドバタイズしたデータを含む辞書型
    ///   - RSSI: 周辺機器の現在の受信信号強度インジケータ（RSSI）（デシベル単位）
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
//        if self.config.debug {
//            print(peripheral.description, RSSI.doubleValue)
//        }
        self.sensorDataBluetooth?.update(peripheral, rssi: RSSI.doubleValue)
        
        // 対象機器のみ保持する
//        if let peripheralName = peripheral.name,
//            peripheralName.contains(Const.Bluetooth.kPeripheralName) {
//            // 対象機器のみ保持する
//            self.connectPeripheral = peripheral
//            // 機器に接続
//            print("機器に接続：\(String(describing: peripheral.name))")
//            self.centralManager.connect(peripheral, options: nil)
//        }
    }

    /// 接続成功時
    ///
    /// - Parameters:
    ///   - central: CBCentralManager
    ///   - peripheral: CBPeripheral
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("接続成功")
//        self.connectPeripheral = peripheral
//        self.connectPeripheral?.delegate = self
//        // 指定のサービスを探索
//        if let peripheral = self.connectPeripheral {
//            peripheral.discoverServices([CBUUID(string: Const.Bluetooth.Service.kUUID)])
//        }
        // スキャン停止処理
//        self.stopBluetoothScan()
    }

    /// 接続失敗時
    ///
    /// - Parameters:
    ///   - central: CBCentralManager
    ///   - peripheral: CBPeripheral
    ///   - error: Error
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("接続失敗：\(String(describing: error))")
    }
    
    ///
    /// 接続切断時
    ///
    /// - Parameters:
    ///   - central: CBCentralManager
    ///   - peripheral: CBPeripheral
    ///   - error: Error
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("接続切断：\(String(describing: error))")
    }

}


public class AWBluetoothSensorData:AWSensorData {
    
    init() {
        super.init("bluetooth", header: ["timestamp",
                                        "identifier",
                                         "name",
                                         "rssi",
                                        "label"])
    }
    
    func update(_ peripheral: CBPeripheral, rssi:Double, label:String = ""){
        
        var values:[String] = []
        
        // set timestamp
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        values.append(String(now))
        
        values.append(contentsOf: [peripheral.identifier.uuidString,
                                   peripheral.name ?? "",
                                   String(rssi)])
        values.append(label)
        
        self.save(values)
    }
}
