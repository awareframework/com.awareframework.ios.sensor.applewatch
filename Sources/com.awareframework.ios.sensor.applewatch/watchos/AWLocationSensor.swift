//
//  MotionSensorManager.swift
//  MiQWatch Extension
//
//  Created by Yuuki Nishiyama on 2021/06/01.
//


#if os(iOS)


#elseif os(watchOS)

import CoreLocation
import com_awareframework_ios_core
import com_awareframework_ios_sensor_applewatch_shared

public class AWLocationSensor: AwareSensor, ObservableObject {
    
    public let locationManager = CLLocationManager()
    
    @Published public var geomagnetisms = [AWHeadingPoint]()
    @Published public var locations = [AWLocationPoint]()
    
    var lastBreakTime = Date()
    var timer:Timer? = nil
    var isRunning = false
    
    let TAG = "AWARE::AppleWatch:location"
    
    public var CONFIG = AWLocationSensor.Config()
    public class Config:SensorConfig{
        var activateHeadingSensor = false
        var activateLocationSensor = true
        
    //    kCLLocationAccuracyBestForNavigation
    //    kCLLocationAccuracyBest
    //    kCLLocationAccuracyNearestTenMeters
    //    kCLLocationAccuracyHundredMeters
    //    kCLLocationAccuracyKilometer
    //    kCLLocationAccuracyThreeKilometers
        var accuracyLevel:CLLocationAccuracy = kCLLocationAccuracyHundredMeters
        
        public override init(){
            super.init()
            self.dbTableName =  AWLocationSensorData.databaseTableName
            self.dbPath = AWLocationSensorData.databaseTableName
        }
        
        public override func set(config: Dictionary<String, Any>) {
            super.set(config: config)
        }
        
        public func apply(closure: (_ config: AWLocationSensor.Config ) -> Void) -> Self {
            closure(self)
            return self
        }
    }
    

    
    public init(_ config:AWLocationSensor.Config) {
        super.init()

        self.CONFIG = config
        self.initializeDbEngine(config: config)
        
        self.dbEngine?.dictToModelHandler = { (dict:Dictionary<String, Any>) -> Any  in
            return AWLocationSensorData(dict)
        }
        
        self.dbEngine?.modelToDictHandler = { (model:Any) -> Dictionary<String, Any>  in
            if let model = model as? AWLocationSensorData {
                return model.toDictionary()
            }
            return [:]
        }
        
        super.syncConfig = DbSyncConfig().apply(closure: { config in
            config.serverType = self.CONFIG.serverType
            config.debug = self.CONFIG.debug
            config.batchSize = 100
            config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.applewatch.location.sync.queue")
        })
        
        if let sqliteEngine = self.dbEngine as? SQLiteEngine {
            if let queue = sqliteEngine.getSQLiteInstance() {
                do {
                   try AWLocationSensorData.createTable(queue: queue)
                }catch {
                    if (CONFIG.debug) {
                        print(#function, error)
                    }
                }
            }
        }
    }
    
    
    public override func start(){

        if (self.CONFIG.debug) {
            print(isRunning)
        }
        if (!isRunning) {
            locationManager.delegate = self
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.desiredAccuracy = CONFIG.accuracyLevel

            startLocationSensor()
        }
    }
    
    public override func stop(){
        if(isRunning) {
            stopLocationSensor()
            isRunning = false
        }
    }
    
    public override func sync(force: Bool = false) {
        if let engine = self.dbEngine, let syncConfig = super.syncConfig {
            engine.startSync(syncConfig)
        }
    }
    
    /**
          ==== local functions ====
     */
    
    private func startLocationSensor(){
        
        //    case notDetermined = 0
        //    case restricted = 1
        //    case denied = 2
        //    case authorizedAlways = 3
        //    case authorizedWhenInUse = 4
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if CONFIG.activateHeadingSensor {
                locationManager.startUpdatingHeading()
            }
            if CONFIG.activateLocationSensor {
                locationManager.startUpdatingLocation()
            }
            isRunning = true
            break
        default:
            locationManager.requestAlwaysAuthorization()
            break
        }
    }
    
    private func stopLocationSensor(){
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
    }
    
}

extension AWLocationSensor: CLLocationManagerDelegate {
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
//            self.sensorDataLocation?.update(location, label: self.config.label)
            let data = AWLocationSensorData(timestamp: Int64(location.timestamp.timeIntervalSince1970 * 1000),
                                                            latitude: location.coordinate.latitude,
                                                            longitude: location.coordinate.longitude,
                                                            altitude: location.altitude,
                                                            ellipsoidalAltitude: location.ellipsoidalAltitude,
                                                            horizontalAccuracy: location.horizontalAccuracy,
                                                            verticalAccuracy: location.verticalAccuracy,
                                                            speed: location.speed,
                                                            speedAccuracy: location.speedAccuracy,
                                                            course: location.course,
                                                            courseAccuracy: location.courseAccuracy,
                                                            label: self.CONFIG.label)
            if let sqlite = self.dbEngine as? SQLiteEngine {
                sqlite.save( data.toDictionary() )
                if (self.CONFIG.debug) {
                    print(TAG, location.timestamp, data.latitude, data.longitude)
                }
            }
            
            self.locations.append(AWLocationPoint(date: location.timestamp, value: location))
            if (self.locations.count > 100) {
                self.locations.removeFirst()
            }
        }
    }
    
//    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
//        self.sensorDataHeading?.update(newHeading, label:self.config.label)
//        geomagnetisms.append(AWHeadingPoint(date: newHeading.timestamp, value: newHeading))
//        if geomagnetisms.count > 100 {
//            geomagnetisms.removeFirst()
//        }
//    }
    
    public func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        return true
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print(#function, manager.authorizationStatus)
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            startLocationSensor()
            break
        default:
            break
        }
    }

    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print(#function, status)
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            startLocationSensor()
            break
        default:
            break
        }
    }
}


public struct AWLocationPoint {
    public var date: Date
    public var value: CLLocation
}

public struct AWHeadingPoint{
    public var date: Date
    public var value:CLHeading
}

#endif
