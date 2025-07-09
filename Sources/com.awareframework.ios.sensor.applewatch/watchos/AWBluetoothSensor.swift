//
//  AWBluetoothSensor.swift
//  com.awareframework.ios.sensor.applewatch-watchOS
//
//  Created by Yuuki Nishiyama on 2023/06/07.
//

#if os(iOS)


#elseif os(watchOS)

import Foundation
import CoreBluetooth
import com_awareframework_ios_sensor_applewatch_shared
import com_awareframework_ios_core

public class AWBluetoothSensor: AwareSensor, ObservableObject {
    
    var centralManager:CBCentralManager?
//    var peripheralManager:CBPeripheralManager?
    
//    @Published public var bluetoothDevices = [AWHeadingPoint]()
    
    var isRunning = false
    
    var lastBreakTime = Date()
    var timer:Timer? = nil
    
    var scanTimer:Timer? = nil
    let TAG = "AWARE::AppleWatch:bluetooth"

    public var CONFIG = AWBluetoothSensor.Config()
    
    public class Config:SensorConfig{
        
        public var sensingDurationSeconds = 10.0
        public var sleepDurationSeconds   = 10.0
        
        public override init(){
            super.init()
            self.dbTableName =  AWBluetoothSensorData.databaseTableName
            self.dbPath = AWBluetoothSensorData.databaseTableName
        }
        
        public override func set(config: Dictionary<String, Any>) {
            super.set(config: config)
        }
        
        public func apply(closure: (_ config: AWBluetoothSensor.Config ) -> Void) -> Self {
            closure(self)
            return self
        }
    }
    
    
    public init(_ config:AWBluetoothSensor.Config) {
        super.init()
        self.CONFIG = config
        self.initializeDbEngine(config: config)
        
        self.dbEngine?.dictToModelHandler = { (dict:Dictionary<String, Any>) -> Any  in
            return AWBluetoothSensorData(dict)
        }
        
        self.dbEngine?.modelToDictHandler = { (model:Any) -> Dictionary<String, Any>  in
            if let model = model as? AWBluetoothSensorData {
                return model.toDictionary()
            }
            return [:]
        }
        super.syncConfig = DbSyncConfig().apply(closure: { config in
            config.serverType = self.CONFIG.serverType
            config.debug = self.CONFIG.debug
            config.batchSize = 100
            config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.applewatch.bluetooth.sync.queue")
        })
        
        if let sqliteEngine = self.dbEngine as? SQLiteEngine {
            if let queue = sqliteEngine.getSQLiteInstance() {
                do {
                    try AWBluetoothSensorData.createTable(queue: queue)
                }catch {
                    if (CONFIG.debug) {
                        print(#function, error)
                    }
                }
            }
        }
    }
    
    public override func start(){
        if (!isRunning) {
            isRunning = true
            startBluetoothScan()
        }
    }
    
    public override func stop(){
        if(isRunning) {
            isRunning = false
            self.stopBluetoothScan()
        }
    }
    
    
    public override func sync(force: Bool = false) {
        if let engine = self.dbEngine, let syncConfig = super.syncConfig {
            engine.startSync(syncConfig)
        }
    }
    
    
    
    @objc func startBluetoothScan(){

        if (self.centralManager == nil) {
            self.centralManager = CBCentralManager(delegate: self, queue: nil)
        }
        
        // タイマーを設定する
        self.scanTimer = Timer.scheduledTimer(timeInterval: TimeInterval(self.CONFIG.sensingDurationSeconds),
                                              target: self,
                                              selector: #selector(self.stopBluetoothScan),
                                              userInfo: nil,
                                              repeats: false)
        if (self.CONFIG.debug) {
            print(self.TAG, "Scanning Bluetooth during \(self.CONFIG.sensingDurationSeconds) seconds")
        }
        
        // 機器を検出
         if self.centralManager?.isScanning == false {
             self.centralManager?.scanForPeripherals(withServices: nil, options: nil)
         }
    }
    
    /// スキャン停止
    @objc func stopBluetoothScan() {
        self.centralManager?.stopScan()
        // Timerを削除
        self.scanTimer?.invalidate()
        self.scanTimer = nil
        
        if (isRunning) {
            if (self.CONFIG.debug) {
                print(self.TAG, "Restart scanning Bluetooth session after \(self.CONFIG.sleepDurationSeconds) seconds (if sensor is still active)")
            }
            Timer.scheduledTimer(withTimeInterval: self.CONFIG.sleepDurationSeconds, repeats: false) { t in
                if (self.isRunning){
                    self.startBluetoothScan()
                }else{
                    if (self.CONFIG.debug) { print(self.TAG, "Stop") }
                }
            }
        }else{
            if (self.CONFIG.debug) { print(self.TAG, "Stop") }
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
            print(self.TAG, "Bluetooth PoweredOff")
            break
        case .poweredOn:
            print(self.TAG, "Bluetooth poweredOn")
            self.centralManager?.scanForPeripherals(withServices: nil, options: nil)
            break
        case .resetting:
            print(self.TAG, "Bluetooth resetting")
            break
        case .unauthorized:
            print(self.TAG, "Bluetooth unauthorized")
            break
        case .unknown:
            print(self.TAG, "Bluetooth unknown")
            break
        case .unsupported:
            print(self.TAG, "Bluetooth unsupported")
            break
        @unknown default:
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
        
        let now = Date.now
        let timestamp = Double(now.timeIntervalSince1970 * 1000)
        let data = AWBluetoothSensorData(timestamp: Int64(timestamp),
                                         identifier: peripheral.identifier.uuidString,
                                         name: peripheral.name ?? "",
                                         rssi: RSSI.doubleValue)
        self.dbEngine?.save(data.toDictionary())
        
        if (self.CONFIG.debug) {
            print(self.TAG, now, peripheral.identifier.uuidString, RSSI.doubleValue, peripheral.name ?? "" )
        }
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
//        print("接続成功")
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
//        print("接続失敗：\(String(describing: error))")
    }
    
    ///
    /// 接続切断時
    ///
    /// - Parameters:
    ///   - central: CBCentralManager
    ///   - peripheral: CBPeripheral
    ///   - error: Error
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
//        print("接続切断：\(String(describing: error))")
    }

}


#endif
