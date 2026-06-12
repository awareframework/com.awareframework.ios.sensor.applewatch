//
//  AWHeadingSensor.swift
//  com.awareframework.ios.sensor.applewatch-watchOS
//
//  Created by OpenAI on 2026/06/09.
//

#if os(iOS)

#elseif os(watchOS)

import CoreLocation
import com_awareframework_ios_core
import com_awareframework_ios_sensor_applewatch_shared

public class AWHeadingSensor: AwareSensor, ObservableObject {

    public let locationManager = CLLocationManager()

    @Published public var headings = [AWHeadingPoint]()

    private var isRunning = false
    private let TAG = "AWARE::AppleWatch:heading"

    public var CONFIG = AWHeadingSensor.Config()
    public class Config: SensorConfig {

        public override init() {
            super.init()
            self.dbTableName = AWHeadingSensorData.databaseTableName
            self.dbPath = AWHeadingSensorData.databaseTableName
        }

        public override func set(config: Dictionary<String, Any>) {
            super.set(config: config)
        }

        public func apply(closure: (_ config: AWHeadingSensor.Config) -> Void) -> Self {
            closure(self)
            return self
        }
    }

    public init(_ config: AWHeadingSensor.Config) {
        super.init()
        self.CONFIG = config
        self.initializeDbEngine(config: config)

        super.syncConfig = DbSyncConfig().apply { config in
            config.serverType = self.CONFIG.serverType
            config.debug = self.CONFIG.debug
            config.batchSize = 100
            config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.applewatch.heading.sync.queue")
        }

        if let sqliteEngine = self.dbEngine as? SQLiteEngine,
           let queue = sqliteEngine.getSQLiteInstance() {
            do {
                try AWHeadingSensorData.createTable(queue: queue)
            } catch {
                if CONFIG.debug {
                    print(#function, error)
                }
            }
        }
    }

    public override func start() {
        guard !isRunning else { return }

        locationManager.delegate = self

        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingHeading()
            isRunning = true
        default:
            locationManager.requestAlwaysAuthorization()
        }
    }

    public override func stop() {
        guard isRunning else { return }
        locationManager.stopUpdatingHeading()
        isRunning = false
    }

    public override func sync(force: Bool = false) {
        if let engine = self.dbEngine, let syncConfig = super.syncConfig {
            engine.startSync(syncConfig)
        }
    }
}

extension AWHeadingSensor: CLLocationManagerDelegate {

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let data = AWHeadingSensorData(
            timestamp: Int64(newHeading.timestamp.timeIntervalSince1970 * 1000),
            trueHeading: newHeading.trueHeading,
            magneticHeading: newHeading.magneticHeading,
            headingAccuracy: newHeading.headingAccuracy,
            x: newHeading.x,
            y: newHeading.y,
            z: newHeading.z,
            label: self.CONFIG.label
        )
        self.dbEngine?.save([data])

        headings.append(AWHeadingPoint(date: newHeading.timestamp, value: newHeading))
        if headings.count > 100 {
            headings.removeFirst()
        }

        if CONFIG.debug {
            print(TAG, newHeading.timestamp, data.trueHeading, data.magneticHeading)
        }
    }

    public func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if CONFIG.debug {
            print(TAG, error)
        }
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if !isRunning {
                locationManager.startUpdatingHeading()
                isRunning = true
            }
        default:
            break
        }
    }

    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            if !isRunning {
                locationManager.startUpdatingHeading()
                isRunning = true
            }
        default:
            break
        }
    }
}

#endif
