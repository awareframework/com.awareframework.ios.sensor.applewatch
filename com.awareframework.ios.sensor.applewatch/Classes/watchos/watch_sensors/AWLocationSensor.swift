//
//  MotionSensorManager.swift
//  MiQWatch Extension
//
//  Created by Yuuki Nishiyama on 2021/06/01.
//


#if os(iOS)


#elseif os(watchOS)

import CoreLocation

public class AWLocationSensor: NSObject, ObservableObject {
    
    public let locationManager = CLLocationManager()
    
    var sensorDataLocation:AWLocationSensorData?
    var sensorDataHeading:AWHeadingSensorData?

    @Published public var geomagnetisms = [AWHeadingPoint]()
    @Published public var locations = [AWLocationPoint]()
    
    var lastBreakTime = Date()
    var timer:Timer? = nil
    var isRunning = false
    let fileTransferManager = FileTransferManager()
    public var config = AWSensorConfig()
    
    var accuracyLevel:CLLocationAccuracy = kCLLocationAccuracyHundredMeters
    
    //            kCLLocationAccuracyBestForNavigation    デフォルト
    //            kCLLocationAccuracyBest    最高精度
    //            kCLLocationAccuracyNearestTenMeters    10m以内
    //            kCLLocationAccuracyHundredMeters    100m以内
    //            kCLLocationAccuracyKilometer    1km以内
    //            kCLLocationAccuracyThreeKilometers    3km以内
    
    override init() {
        super.init()
    }
    
    func start(_ config:AWSensorConfig){
        self.config = config
        if (!isRunning) {
            isRunning = true
            locationManager.delegate = self
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.desiredAccuracy = accuracyLevel


            sensorDataLocation = AWLocationSensorData()
            sensorDataHeading = AWHeadingSensorData()
            sensorDataLocation?.openFileHandler()
            sensorDataHeading?.openFileHandler()
            startLocationSensor()
        }
    }
    
    func stop(){
        if(isRunning) {
            stopLocationSensor()
            isRunning = false
            if let sensorData = sensorDataLocation {
                sensorData.closeFileHandler()
                fileTransferManager.transferFile(fileURL: sensorData.filePath, debug: self.config.debug)
            }
            if let sensorData = sensorDataHeading {
                sensorData.closeFileHandler()
                fileTransferManager.transferFile(fileURL: sensorData.filePath, debug: self.config.debug)
            }
        }
    }
    
    private func startLocationSensor(){
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if config.activateHeadingSensor {
                locationManager.startUpdatingHeading()
            }
            if config.activateLocationSensor {
                locationManager.startUpdatingLocation()
            }
            
            // Configure a timer to fetch the data.
            if self.timer == nil {

                lastBreakTime = Date()
                self.timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(self.config.autoFileTransferInterval),
                                                  repeats: true,
                                                  block: { timer in
                    let now = Date()
                    
                    if let data = self.sensorDataLocation {
                        data.closeFileHandler()
                        let originalFileURL = data.filePath
                        self.fileTransferManager.transferFile( fileURL: originalFileURL,
                                                               debug: self.config.debug)
                    }
                    self.sensorDataLocation = AWLocationSensorData()
                    self.sensorDataLocation?.openFileHandler()
                    

                    if let data = self.sensorDataHeading {
                        data.closeFileHandler()
                        let originalFileURL = data.filePath
                        self.fileTransferManager.transferFile(fileURL: originalFileURL,
                                                              debug: self.config.debug)
                    }
                    self.sensorDataHeading = AWHeadingSensorData()
                    self.sensorDataHeading?.openFileHandler()
                    
                    self.lastBreakTime = now
                })
            
                    
                // Add the timer to the current run loop.
                RunLoop.current.add(self.timer!, forMode: .default)
            }
            
            break
        default:
            locationManager.requestAlwaysAuthorization()
            break
        }
        //    case notDetermined = 0
        //    case restricted = 1
        //    case denied = 2
        //    case authorizedAlways = 3
        //    case authorizedWhenInUse = 4
    }
    private func stopLocationSensor(){
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
    }
    
}

extension AWLocationSensor: CLLocationManagerDelegate {
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            self.sensorDataLocation?.update(location, label: self.config.label)
            self.locations.append(AWLocationPoint(date: location.timestamp, value: location))
            if (self.locations.count > 100) {
                self.locations.removeFirst()
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        self.sensorDataHeading?.update(newHeading, label:self.config.label)
        geomagnetisms.append(AWHeadingPoint(date: newHeading.timestamp, value: newHeading))
        if geomagnetisms.count > 100 {
            geomagnetisms.removeFirst()
        }
    }
    
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


public class AWLocationSensorData:AWSensorData {
    
    init() {
        super.init("location", header: ["timestamp",
                                        "latitude",
                                        "longitude",
                                        "altitude",
                                        "ellipsoidal_altitude",
                                        "horizontal_accuracy",
                                        "vertical_accuracy",
                                        "speed",
                                        "speed_accuracy",
                                        "course",
                                        "course_accuracy",
                                        "label"])
    }
    
    func update(_ location: CLLocation, label:String = ""){
        
        var values:[String] = []
        
        // set timestamp
        let now = Int64(location.timestamp.timeIntervalSince1970 * 1000)
        values.append(String(now))
        
        values.append(contentsOf: [String(location.coordinate.latitude),
                                   String(location.coordinate.longitude),
                                   String(location.altitude),
                                   String(location.ellipsoidalAltitude),
                                   String(location.horizontalAccuracy),
                                   String(location.verticalAccuracy),
                                   String(location.speed),
                                   String(location.speedAccuracy),
                                   String(location.course),
                                   String(location.courseAccuracy)])
        
        values.append(label)
        
        self.save(values)
    }
}

public class AWHeadingSensorData:AWSensorData {
    
    init() {
        super.init("heading", header: ["timestamp",
                                       "true_heading",
                                       "magnetic_heading",
                                       "heading_accuracy",
                                       "x",
                                       "y",
                                       "z",
                                       "label"])
    }
    
    func update(_ heading: CLHeading, label:String = ""){
        
        var values:[String] = []
        
        // set timestamp
        let now = Int64(heading.timestamp.timeIntervalSince1970 * 1000)
        values.append(String(now))
        
        values.append(contentsOf: [
            String(heading.trueHeading),
            String(heading.magneticHeading),
            String(heading.headingAccuracy),
            String(heading.x),
            String(heading.y),
            String(heading.z)
        ])
        
        values.append(label)
        
        self.save(values)
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
