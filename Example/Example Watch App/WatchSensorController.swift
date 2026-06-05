import Foundation
import SwiftUI
import WatchConnectivity

import com_awareframework_ios_core
import com_awareframework_ios_sensor_applewatch_watchOS

@MainActor
final class WatchSensorController: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var motionEnabled = true
    @Published var batteryEnabled = true
    @Published var deviceEnabled = true
    @Published var healthKitEnabled = true
    @Published var locationEnabled = false
    @Published var audioEnabled = false
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

    private lazy var healthKit = AWHealthKitSensor(AWHealthKitSensor.Config().apply { config in
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

    func activate() {
        _ = AWWCSessionManager.shared
        updateReachability()
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
        if motionEnabled { sensors.append(motion) }
        if batteryEnabled { sensors.append(battery) }
        if deviceEnabled { sensors.append(device) }
        if healthKitEnabled { sensors.append(healthKit) }
        if locationEnabled { sensors.append(location) }
        if audioEnabled { sensors.append(audio) }
        return sensors
    }

    private func updateReachability() {
        isPhoneReachable = WCSession.isSupported() && WCSession.default.isReachable
    }
}
