import Foundation
import SwiftUI
import WatchConnectivity

import com_awareframework_ios_core
import com_awareframework_ios_sensor_applewatch_watchOS

// [Change 1] Keys for persisting recording state and sensor toggles in UserDefaults
//   isRunning: recording on/off state
//   motion-audio: enabled/disabled state of each sensor
private enum UDKey {
    static let isRunning      = "watch_example_isRunning"
    static let motion         = "watch_example_motionEnabled"
    static let battery        = "watch_example_batteryEnabled"
    static let device         = "watch_example_deviceEnabled"
    static let healthKit      = "watch_example_healthKitEnabled"
    static let location       = "watch_example_locationEnabled"
    static let audio          = "watch_example_audioEnabled"
}

@MainActor
final class WatchSensorController: NSObject, ObservableObject {
    // [Change 2] Persist each property to UserDefaults via didSet
    //   State is saved immediately on every change and survives app termination
    @Published var isRunning: Bool {
        didSet { UserDefaults.standard.set(isRunning, forKey: UDKey.isRunning) }
    }
    @Published var motionEnabled: Bool {
        didSet { UserDefaults.standard.set(motionEnabled, forKey: UDKey.motion) }
    }
    @Published var batteryEnabled: Bool {
        didSet { UserDefaults.standard.set(batteryEnabled, forKey: UDKey.battery) }
    }
    @Published var deviceEnabled: Bool {
        didSet { UserDefaults.standard.set(deviceEnabled, forKey: UDKey.device) }
    }
    @Published var healthKitEnabled: Bool {
        didSet { UserDefaults.standard.set(healthKitEnabled, forKey: UDKey.healthKit) }
    }
    @Published var locationEnabled: Bool {
        didSet { UserDefaults.standard.set(locationEnabled, forKey: UDKey.location) }
    }
    @Published var audioEnabled: Bool {
        didSet { UserDefaults.standard.set(audioEnabled, forKey: UDKey.audio) }
    }
    @Published var isPhoneReachable = false
    @Published var statusMessage = "Ready"

    let deviceId = AwareUtils.getCommonDeviceId()

    private lazy var motion = AWMotionSensor(AWMotionSensor.Config().apply { config in
        config.motionSensorHz = 10
        config.saveIntervalSeconds = 10
        config.debug = true
    })

    private lazy var battery = AWBatterySensor(AWBatterySensor.Config().apply { config in
        config.intervalSeconds = 60
        config.debug = true
    })

    private lazy var device = AWDeviceSensor(AWDeviceSensor.Config().apply { config in
        config.debug = true
        config.pairedDeviceIdReceivedHandler = { deviceId in
            Task { @MainActor in
                self.statusMessage = deviceId.isEmpty ? "Phone ID unavailable" : "Phone paired"
            }
        }
    })

    // [Change 5] Renamed AWHealthKitSensor → AWHeartRateSensor to follow library-side class rename
    private lazy var healthKit = AWHeartRateSensor(AWHeartRateSensor.Config().apply { config in
        config.debug = true
    })

    private lazy var location = AWLocationSensor(AWLocationSensor.Config().apply { config in
        config.debug = true
    })

    private lazy var audio = AWAudioSensor(AWAudioSensor.Config().apply { config in
        config.debug = true
        config.activateAmbientNoiseSensor = true
        config.activateAudioClassificationSensor = false
        config.storeOnlyTopK = 5
    })

    var activeSensorCount: Int {
        selectedSensors().count
    }

    // [Change 3] Restore previous state from UserDefaults on init
    //   On first launch, bool(forKey:) returns false, so all sensors and recording default to off
    override init() {
        let ud = UserDefaults.standard
        isRunning      = ud.bool(forKey: UDKey.isRunning)
        motionEnabled  = ud.bool(forKey: UDKey.motion)
        batteryEnabled = ud.bool(forKey: UDKey.battery)
        deviceEnabled  = ud.bool(forKey: UDKey.device)
        healthKitEnabled = ud.bool(forKey: UDKey.healthKit)
        locationEnabled  = ud.bool(forKey: UDKey.location)
        audioEnabled     = ud.bool(forKey: UDKey.audio)
        super.init()
    }

    // [Change 4] Auto-resume sensors on app launch if recording was active last session
    func activate() {
        _ = AWWCSessionManager.shared
        updateReachability()
        if isRunning {
            start()
        }
    }

    func applyiPhoneSettings() {
        AWWCSessionManager.shared.applyiPhoneSettings { [weak self] settings in
            guard let self else { return }
            Task { @MainActor in
                if let v = settings["watch_motion_enabled"] as? Bool { self.motionEnabled = v }
                if let v = settings["watch_battery_enabled"] as? Bool { self.batteryEnabled = v }
                if let v = settings["watch_device_enabled"] as? Bool { self.deviceEnabled = v }
                if let v = settings["watch_healthkit_enabled"] as? Bool { self.healthKitEnabled = v }
                if let v = settings["watch_location_enabled"] as? Bool { self.locationEnabled = v }
                if let v = settings["watch_audio_enabled"] as? Bool { self.audioEnabled = v }
                if let v = settings["motion_sensor_hz"] as? Int { self.motion.CONFIG.motionSensorHz = v }
                self.statusMessage = "Settings applied from iPhone"
            }
        }
    }

    func start() {
        let sensors = selectedSensors()
        guard !sensors.isEmpty else {
            isRunning = false
            statusMessage = "No sensors selected"
            return
        }

        AWSensorManager.shared.requestPermissionNotification { _, _ in }
        AWSensorManager.shared.set(sensors: sensors) {
            AWSensorManager.shared.requestPermissionHealthKit { _, _ in }
            AWSensorManager.shared.start(useWorkoutSession: self.healthKitEnabled) {
                Task { @MainActor in
                    self.statusMessage = "\(sensors.count) sensors running"
                    self.updateReachability()
                }
            }
        }
    }

    func stop() {
        AWSensorManager.shared.stop {
            Task { @MainActor in
                self.statusMessage = "Stopped"
                self.updateReachability()
            }
        }
    }

    func sync() {
        statusMessage = "Sync requested"
        AWSensorManager.shared.sync(force: true)
        updateReachability()
    }

    func transfer() {
        let sensors = selectedSensors()
        guard !sensors.isEmpty else {
            statusMessage = "No sensors selected"
            return
        }

        statusMessage = "Transfer started..."
        AWDataTransferManager.shared.transferData(sensors: sensors) { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.statusMessage = "Transfer failed: \(error.localizedDescription)"
                } else {
                    self?.statusMessage = "Transfer complete"
                }
            }
        }
    }

    private func selectedSensors() -> [AwareSensor] {
        var sensors: [AwareSensor] = []
        if motionEnabled  { sensors.append(motion) }
        if batteryEnabled { sensors.append(battery) }
        if deviceEnabled  { sensors.append(device) }
        if healthKitEnabled { sensors.append(healthKit) }
        if locationEnabled  { sensors.append(location) }
        if audioEnabled     { sensors.append(audio) }
        return sensors
    }

    private func updateReachability() {
        isPhoneReachable = WCSession.isSupported() && WCSession.default.isReachable
    }
}
