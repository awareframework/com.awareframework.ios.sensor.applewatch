# AWARE: AppleWatch

[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![License](https://github.com/awareframework/com.awareframework.ios.sensor.applewatch/blob/main/LICENSE)](LICENSE)

## Overview
**AWARE-watchOS** is a passive wearable sensing framework for watchOS. This framework allows us to continually collect multiple sensor data on smartwatches with a minimum workload. Especially, this framework collects eight sensors on the smartwatch and transfers the collected data as zlib-compressed JSON chunks to the paired iPhone via WatchConnectivity. The transferred data is managed on an eco-system of the AWARE framework. Moreover, as an option, data can be stored or streamed in the paired smartphone application.

### Supported sensors
The latest version of the framework supports the following sensors:
* Accelerometer
* Barometer
* Battery
* Bluetooth
* Rotation
* Location
* Microphone
    * Raw audio
    * Ambient noise level
    * [Sound classification](https://developer.apple.com/documentation/soundanalysis/classifying_sounds_in_an_audio_stream) with a sound classification model provided by Apple (which can classify 303 sound types on a device)
    * Sound classification with own CoreML model
* Heatrate

### Screenshots
![main_screen](/images/screenshots/main.jpeg)
![sensor_settings](/images/screenshots/sensors.jpeg)
![sound](/images/screenshots/sound.PNG)
![accelerometer](/images/screenshots/acc.PNG)
![noise](/images/screenshots/noise.PNG)


### Design
The following figure illustrates the design of this framework. This framework is composed of two major components: watchOS and iOS side. During data collection, the watchOS-side component runs as an exercise application to collect data in the background. Collected sensor data is exported from SQLite in paginated chunks, encoded as JSON (columnar format by default), zlib-compressed, and transferred to the paired iPhone via the `WatchConnectivity` file transfer API (`WCSession.transferFile`).

![design](/images/aware-watch.png)

### Battery consumption
Battery consumption is dependent on the types and settings of sensors.
Our lab study shows that this framework works for 16 to 29 hours with single sensors. High-sampling rate and more extensive data size generated sensors tend to consume battery.

![battery_consumption](/images/battery_full.png)

For more detailes, please check out the paper as follows:
"[Smartwatch-Based Sensing Framework for Continuous Data Collection: Design and Implementation](https://dl.acm.org/doi/10.1145/3594739.3612874)," Y. Nishiyama and K. Sezaki, UbiComp2023 Workshop (Mental Health: Sensing & Intervention)


## Requirements
iOS 16 or later (iPhone target)
watchOS 8 or later (Apple Watch target)

## Installation

You can integrate this framework into your project via Swift Package Manager (SwiftPM).

### SwiftPM
1. Open Package Manager Windows
    * Open `Xcode` -> Select `Menu Bar` -> `File` -> `App Package Dependencies...`

2. Find the package using the manager
    * Select `Search Package URL` and type `https://github.com/awareframework/com.awareframework.ios.sensor.applewatch.git`

3. Import package both `iOS` and `watchOS` targets.



## Permissions
To enable background sensing on Apple Watch, you need to change **Capability** and **background mode** settings on Xcode.

### Capability
Please add `Background Modes` and `HealthKit` on **Signing & Capabilities** tab using **+ Capability** button.

![background_mode](/images/background_modes.png)


### Info.plist
In addition, please add pairs of Key and Value into `WatchOS Target Properties` if you need.
The required pairs of Key and Value depend on what you are going to use in your application.

![info.plist](/images/info_plist.png)


## Sensor Configuration

### AWMotionSensor.Config (watchOS)

Class to hold the configuration of the sensor.

#### Fields

+ `motionSensorHz: Int`: Sampling rate in Hz. (default = `10`)
+ `saveIntervalSeconds: Int`: How often buffered records are flushed to the database. (default = `10`)
+ `activateAccelerometerSensor: Bool`: Enable raw accelerometer data collection. (default = `true`)
+ `activateGyroscopeSensor: Bool`: Enable gyroscope data collection. (default = `true`)
+ `activateMagnetometerSensor: Bool`: Enable magnetometer data collection. (default = `true`)
+ `activateDeviceMotionSensor: Bool`: Enable device-motion (attitude, gravity, rotation rate) data collection. (default = `true`)

Each sub-sensor can be toggled independently. Fields for a disabled sub-sensor are stored as `0` in the database.

### AWAudioSensor.Config (watchOS)

Class to hold the configuration of the sensor.

#### Fields

+ `activateAmbientNoiseSensor: Bool`: Enable decibel level measurement. (default = `false`)
+ `activateAudioClassificationSensor: Bool`: Enable sound label classification via SoundAnalysis. (default = `false`)
+ `dutyCycleEnabled: Bool`: Enable duty cycle control; audio analysis pauses during the rest phase while the microphone tap stays active. (default = `true`)
+ `activeDuration: TimeInterval`: Duration of the active processing phase in seconds. (default = `60`)
+ `restDuration: TimeInterval`: Duration of the rest phase in seconds. (default = `180`)
+ `storeOnlyTopK: Int?`: Store only the top-K classifications by confidence. `nil` stores all. (default = `nil`)

Call `currentDutyCycleStatus()` to query the current phase (`active` or `rest`) and the time at which the phase ends.

### AppleWatchSensor.Config (iOS)

Class to hold the configuration of the sensor.

#### Fields

+ `motionSensorHz: Int`: Motion sampling rate sent to the Watch. (default = `10`)
+ `watchMotionAccelerometerEnabled: Bool`: Enable accelerometer on the Watch. (default = `true`)
+ `watchMotionDeviceMotionEnabled: Bool`: Enable device motion on the Watch. (default = `true`)
+ `watchAudioAmbientNoiseEnabled: Bool`: Enable ambient noise level processing on the Watch. (default = `true`)
+ `watchAudioClassificationEnabled: Bool`: Enable audio label classification on the Watch. (default = `true`)
+ `watchAudioDutyCycleEnabled: Bool`: Enable duty cycle audio processing on the Watch. (default = `true`)
+ `watchAudioActiveDuration: TimeInterval`: Watch audio active phase duration in seconds. (default = `60`)
+ `watchAudioRestDuration: TimeInterval`: Watch audio rest phase duration in seconds. (default = `180`)
+ `fileTransferIntervalSeconds: Double`: How often Watch data is transferred to the iPhone. (default = `900`)
+ `watchMotionEnabled: Bool`: Enable the motion sensor on the Watch. (default = `true`)
+ `watchBatteryEnabled: Bool`: Enable the battery sensor on the Watch. (default = `true`)
+ `watchAudioEnabled: Bool`: Enable the audio/noise sensor on the Watch. (default = `false`)
+ `watchBackgroundSessionType: AWBackgroundSessionType`: Background runtime source for the Watch app: `.none`, `.workout`, or `.microphone`. (default = `.microphone`)

These values are included in the settings dictionary sent to the Watch via `get_settings`. Apply them manually in `applyiPhoneSettings()` as shown in the code examples below.

### Background session type

`AWSensorManager` can keep the Watch app active using one of three modes:

| Mode | Description |
|------|-------------|
| `.none` | Does not start a background runtime session. Use only when foreground collection is enough. |
| `.workout` | Starts an `HKWorkoutSession` with activity type `.other`. This can appear as an exercise/workout session in Apple fitness surfaces and should not be used when no workout history must remain. |
| `.microphone` | Starts a no-op microphone capture session for background audio runtime. It does not save audio or ambient-noise records unless `AWAudioSensor` itself is enabled. Requires microphone permission and the audio background mode. |

## Development
The following source code shows a minimum sample code for collecting sensor data on a smartwatch. A developer has to write source codes on both iOS and wathcOS as follows.

### iOS
```swift
import com_awareframework_ios_sensor_core
import com_awareframework_ios_sensor_applewatch
```

```swift
let appleWatch = AppleWatchSensor(AppleWatchSensor.Config().apply { config in
    config.debug = true
})

SensorManager.shared.addSensors([appleWatch])
SensorManager.shared.startAllSensors()
```

More detailed sample codes can be found [here](https://github.com/awareframework/com.awareframework.ios.sensor.applewatch/blob/d16646411f5caf89d19797a187fe5c489d93f2eb/Example/com.awareframework.ios.sensor.applewatch/AppDelegate.swift#L30).


### watchOS

```swift
import com_awareframework_ios_sensor_applewatch
```

```swift
let motionSensor = AWMotionSensor.shared.start(AWMotionSensor.Config().apply { config in
    config.motionSensorHz = 50
    config.debug = true
})
motionSensor.start()

AWSensorManager.shared.set(sensors: [motionSensor])

// Transfer all locally stored sensor data to the paired iPhone.
AWSensorManager.shared.transferAllData { error in
    if let error { print("Transfer failed: \(error)") }
}

// Transfer only new records since the last transfer.
AWSensorManager.shared.transferIncrementalData { error in
    if let error { print("Transfer failed: \(error)") }
}

// Transfer only new records and delete them from the watch database after transfer.
AWSensorManager.shared.transferIncrementalData(deleteAfterTransfer: true) { error in
    if let error { print("Transfer failed: \(error)") }
}
```
More detailed sample codes can be found [here](https://github.com/awareframework/com.awareframework.ios.sensor.applewatch/blob/909f71e0aadc2c05cfa0fb7f21e5584ebb095620/Example/AwareWatch%20Watch%20App/ContentView.swift#L31).


## Data Transfer

Sensor data is transferred to the paired iPhone using `AWDataTransferManager`, accessible as a singleton via `AWDataTransferManager.shared`.

### How it works

1. **Preparation** — sensor records are read from SQLite in pages (default 500 records per page) to keep peak memory usage low.
2. **Encoding** — each page is serialised as JSON. When `useColumnarFormat` is `true` (default), fields that are constant across all rows (e.g. `deviceId`, `timezone`) are stored once as scalars while varying fields (e.g. `timestamp`, `accX`) are stored as arrays. This reduces payload size by 3–5× compared to a row-oriented format.
3. **Compression** — the JSON payload is compressed with zlib before being written to a temporary file.
4. **Transfer** — each compressed chunk file is queued with `WCSession.transferFile`, which delivers it reliably to the paired iPhone even if the watch app moves to the background.
5. **Clean-up** — temporary chunk files are deleted automatically once all transfers complete.

### File naming

Each chunk file is named using the pattern:

```
aw_<tableName>_<sessionTimestamp>_<chunkIndex>of<totalChunks>.json.zlib
```

Each file is accompanied by WatchConnectivity metadata:

| Key | Value |
|-----|-------|
| `type` | `"AWDataTransfer"` |
| `tableName` | source table name in SQLite |
| `chunkIndex` | 1-based index of this chunk |
| `totalChunks` | total number of chunks for this table |
| `deviceId` | AWARE device identifier |

### Transfer modes

`AWDataTransferManager` supports two transfer modes controlled by the `transferMode` property.

| Mode | Description |
|------|-------------|
| `.all` (default) | Every record in the database is transferred on each call, regardless of previous runs |
| `.incremental` | Only records that have not been transferred before are sent. The highest record ID successfully transferred is saved in `UserDefaults` on the watch and used as the starting cursor on the next call. On the very first incremental call (no bookmark saved yet), all records are transferred |

An optional `deleteAfterTransfer` flag causes transferred records to be deleted from the **watch-side SQLite database** once all file transfers complete successfully. This keeps watch storage lean when data is no longer needed locally.

### Configuration

+ `recordsPerChunk: Int`: Number of sensor records packed into each compressed chunk. (default = `500`)
+ `useColumnarFormat: Bool`: Encode JSON in columnar format (smaller payload). (default = `true`)
+ `transferMode: AWTransferMode`: Transfer all records or only new records since the last successful transfer. (default = `.all`)
+ `deleteAfterTransfer: Bool`: Delete transferred records from the watch-side database after all transfers complete. (default = `false`)
+ `debug: Bool`: Print verbose progress logs to the console. (default = `false`)

```swift
AWDataTransferManager.shared.recordsPerChunk = 1000
AWDataTransferManager.shared.useColumnarFormat = true
AWDataTransferManager.shared.transferMode = .incremental
AWDataTransferManager.shared.deleteAfterTransfer = true
AWDataTransferManager.shared.debug = true
```

### Transfer states

`AWDataTransferManager` publishes its current state as an `AWTransferState` value:

| State | Description |
|-------|-------------|
| `.idle` | No transfer in progress |
| `.preparing(sensor:)` | Building chunk files for the named sensor table |
| `.transferring` | Chunk files are queued and being delivered |
| `.completed` | All chunks delivered successfully |
| `.failed(message:)` | Transfer ended with an error |

### API

```swift
// Transfer all records (default behaviour)
AWSensorManager.shared.transferAllData { error in
    // called on main thread when all transfers finish or fail
}

// Transfer all records and delete them from the watch database afterwards
AWSensorManager.shared.transferAllData(deleteAfterTransfer: true) { error in … }

// Transfer only new records since the last successful transfer
AWSensorManager.shared.transferIncrementalData { error in … }

// Transfer only new records and delete them from the watch database afterwards
AWSensorManager.shared.transferIncrementalData(deleteAfterTransfer: true) { error in … }

// Lower-level access via AWDataTransferManager directly
AWDataTransferManager.shared.transferMode = .incremental
AWDataTransferManager.shared.deleteAfterTransfer = true
AWDataTransferManager.shared.transferData(sensors: sensors) { error in … }

// Cancel all in-flight transfers
AWDataTransferManager.shared.cancel()
```

#### Incremental bookmark

When `transferMode == .incremental`, the highest record ID transferred in a session is saved in `UserDefaults` under the key:

```
com.awareframework.applewatch.lastTransferred.<tableName>
```

This bookmark persists across app launches. To reset it and force a full retransfer, delete the key from `UserDefaults` or call `transferAllData` once (which ignores the bookmark).

### SwiftUI progress views (watchOS only)

The library ships two SwiftUI components for visualising transfer progress.

**`AWDataTransferProgressView`** — full-screen scrollable view showing overall progress and a per-chunk breakdown:

```swift
import com_awareframework_ios_sensor_applewatch

struct TransferView: View {
    var body: some View {
        AWDataTransferProgressView()              // uses .shared
        // AWDataTransferProgressView(manager: myManager)  // custom instance
    }
}
```

**`AWDataTransferBadge`** — compact circular progress indicator suitable for toolbars or smaller slots:

```swift
AWDataTransferBadge()
```

Both views are `ObservableObject`-backed and update automatically as the transfer progresses.

## Server Upload

Sensor data can be uploaded to a remote server from either the **Apple Watch** or the **paired iPhone**. The two paths have different trade-offs; uploading directly from the Watch is the most efficient in most cases.

```
Apple Watch ──(WatchConnectivity)──▶ iPhone ──(HTTP)──▶ Server   ← 2 hops
Apple Watch ──────────(HTTP)──────────────────────────▶ Server   ← 1 hop  ✓ recommended
```

### Option A — Upload directly from Apple Watch (recommended)

Uploading from the Watch skips the WatchConnectivity relay entirely.  Data travels in a single hop from the source to the server, which means:

- No dependency on the paired iPhone being nearby or reachable.
- Lower end-to-end latency and fewer moving parts.
- Simpler code — one call initiates the full upload.

Call `AWSensorManager.shared.sync(dbHost:)` on the Watch side at any point after sensors have been started.

```swift
// watchOS
AWSensorManager.shared.set(sensors: [motionSensor, noiseSensor, ...]) {
    AWSensorManager.shared.start { }
}

// Trigger upload (e.g. in a background task, on a timer, or when the workout ends)
AWSensorManager.shared.sync(
    force: true,
    dbHost: "https://your-aware-server.example.com/index.php"
)
```

`sync(dbHost:)` iterates over every registered sensor, sets the server URL on its SQLite engine, and calls `sync()` — which uploads all locally stored records to the AWARE server in batches.

You can also trigger it from a single sensor's engine:

```swift
motionSensor.dbEngine?.config.host = "https://your-aware-server.example.com/index.php"
motionSensor.sync(force: true)
```

#### Fetching settings from the paired iPhone

Instead of hard-coding the server URL on the Watch, you can pull it from the iPhone at runtime using `AWWCSessionManager.shared.applyiPhoneSettings()`.  This method sends a `get_settings` request to the iPhone, reads the response, and applies the returned values to every sensor registered in `AWSensorManager`.

Configure the iPhone side once:

```swift
// iOS
let appleWatch = AppleWatchSensor(AppleWatchSensor.Config().apply { config in
    config.dbHost = "https://your-aware-server.example.com/index.php"
    config.motionSensorHz = 50
    config.fileTransferIntervalSeconds = 900
})
SensorManager.shared.addSensors([appleWatch])
SensorManager.shared.startAllSensors()
```

Then on the Watch, call `applyiPhoneSettings()` after sensors are started:

```swift
// watchOS
AWSensorManager.shared.set(sensors: [motionSensor]) {
    AWSensorManager.shared.start { }
}

AWWCSessionManager.shared.applyiPhoneSettings { settings in
    // db_host / label / debug are applied automatically to all sensors.
    // motion_sensor_hz and file_transfer_interval_seconds must be applied manually:
    let hz       = settings["motion_sensor_hz"] as? Int ?? 30
    let interval = settings["file_transfer_interval_seconds"] as? Double ?? 900
    motionSensor.CONFIG.motionSensorHz = hz
    AWDataTransferManager.shared.transferIntervalSeconds = interval

    // Upload immediately using the server URL fetched from iPhone
    AWSensorManager.shared.sync(force: true)
}
```

Settings returned by `get_settings`:

| Key | Type | Auto-applied by `applyiPhoneSettings` | Description |
|-----|------|---------------------------------------|-------------|
| `db_host` | `String` | ✓ `dbEngine.config.host` | AWARE server URL. Omitted when not set on the iPhone. Set by QR code scan (`server_host`/`server_port`) |
| `label` | `String` | ✓ `sensor.set(label:)` | Data label. Set by QR code scan (`study_key`) |
| `debug` | `Bool` | ✓ `syncConfig.debug` | Debug logging flag |
| `motion_sensor_hz` | `Int` | — (apply manually) | Motion sensor sampling rate |
| `watch_motion_accelerometer_enabled` | `Bool` | — (apply manually) | Whether to run the accelerometer inside the Watch motion sensor |
| `watch_motion_device_motion_enabled` | `Bool` | — (apply manually) | Whether to run device motion inside the Watch motion sensor |
| `file_transfer_interval_seconds` | `Double` | — (apply manually) | Watch→iPhone transfer interval |
| `watch_motion_enabled` | `Bool` | — (apply manually) | Whether to run the motion sensor on the Watch |
| `watch_battery_enabled` | `Bool` | — (apply manually) | Whether to run the battery sensor on the Watch |
| `watch_device_enabled` | `Bool` | — (apply manually) | Whether to run the device sensor on the Watch |
| `watch_healthkit_enabled` | `Bool` | — (apply manually) | Whether to run the HealthKit (heart rate) sensor on the Watch |
| `watch_location_enabled` | `Bool` | — (apply manually) | Whether to run the location sensor on the Watch |
| `watch_audio_enabled` | `Bool` | — (apply manually) | Whether to run the audio/noise sensor on the Watch |
| `watch_audio_ambient_noise_enabled` | `Bool` | — (apply manually) | Whether to run ambient noise level processing on the Watch |
| `watch_audio_classification_enabled` | `Bool` | — (apply manually) | Whether to run audio label classification on the Watch |
| `watch_audio_duty_cycle_enabled` | `Bool` | — (apply manually) | Whether to duty-cycle Watch audio processing while keeping microphone capture active |
| `watch_audio_active_duration` | `Double` | — (apply manually) | Watch audio processing active duration in seconds |
| `watch_audio_rest_duration` | `Double` | — (apply manually) | Watch audio processing rest duration in seconds |
| `watch_uwb_enabled` | `Bool` | — (apply manually) | Whether to run the UWB sensor on the Watch |
| `watch_bluetooth_enabled` | `Bool` | — (apply manually) | Whether to run the Bluetooth sensor on the Watch |

Sensor enable/disable flags are not applied automatically because `applyiPhoneSettings` does not know which sensor instances the caller has created. Apply them manually in the completion handler as shown below.

```swift
// watchOS — apply sensor on/off flags received from iPhone
AWWCSessionManager.shared.applyiPhoneSettings { settings in
    // db_host / label / debug are applied automatically.
    // Sensor flags and Hz must be applied by the caller:
    let motionOn    = settings["watch_motion_enabled"]    as? Bool ?? true
    let batteryOn   = settings["watch_battery_enabled"]   as? Bool ?? true
    let locationOn  = settings["watch_location_enabled"]  as? Bool ?? false
    let audioOn     = settings["watch_audio_enabled"]     as? Bool ?? false
    let hz          = settings["motion_sensor_hz"]        as? Int  ?? 10
    let accOn = settings["watch_motion_accelerometer_enabled"] as? Bool ?? true
    let deviceMotionOn = settings["watch_motion_device_motion_enabled"] as? Bool ?? true
    let ambientNoiseOn = settings["watch_audio_ambient_noise_enabled"] as? Bool ?? true
    let audioClassificationOn = settings["watch_audio_classification_enabled"] as? Bool ?? true
    let audioDutyCycleOn = settings["watch_audio_duty_cycle_enabled"] as? Bool ?? true
    let audioActive = settings["watch_audio_active_duration"] as? Double ?? 60
    let audioRest = settings["watch_audio_rest_duration"] as? Double ?? 180

    // Update your sensor controller state on the main thread
    DispatchQueue.main.async {
        motionSensor.CONFIG.motionSensorHz = hz
        motionSensor.CONFIG.activateAccelerometerSensor = accOn
        motionSensor.CONFIG.activateDeviceMotionSensor = deviceMotionOn
        audioSensor.CONFIG.activateAmbientNoiseSensor = ambientNoiseOn
        audioSensor.CONFIG.activateAudioClassificationSensor = audioClassificationOn
        audioSensor.CONFIG.dutyCycleEnabled = audioDutyCycleOn
        audioSensor.CONFIG.activeDuration = audioActive
        audioSensor.CONFIG.restDuration = audioRest
        var sensorsToStart: [AwareSensor] = []
        if motionOn  { sensorsToStart.append(motionSensor)  }
        if batteryOn { sensorsToStart.append(batterySensor) }
        if locationOn { sensorsToStart.append(locationSensor) }
        if audioOn   { sensorsToStart.append(audioSensor)   }

        AWSensorManager.shared.set(sensors: sensorsToStart) {
            AWSensorManager.shared.start { }
        }
    }
}
```

#### Table names

Each sensor stores its data in a named table in the local SQLite database on the Watch.  The same table name is used when uploading to the AWARE server.

| Sensor | Table name |
|--------|-----------|
| Motion (acc, gyro, gravity …) | `watch_motion` |
| Ambient noise | `watch_ambient_noise` |
| Sound classification | `watch_audio_label` |
| HealthKit (heart rate) | `watch_healthkit` |
| Battery | `watch_battery` |
| Bluetooth | `watch_bluetooth` |
| Location | `watch_location` |
| Heading | `watch_heading` |
| Device info | `watch_device` |

### Option B — Upload from the paired iPhone

If you need to centralise server communication on the iPhone side (e.g. to apply authentication headers or post-process records before upload), you can:

1. Transfer data from the Watch to the iPhone using `AWSensorManager.shared.transferAllData()` or `transferIncrementalData()`.
2. Handle each received chunk on the iPhone via `receivedDataHandler`.
3. Forward it to the server from the iPhone.

Set `dbHost` in the `AppleWatchSensor` config.  The framework stores records received from the Watch in a local SQLite database on the iPhone and uploads them in batches when `sync()` is called.

```swift
// iOS
let appleWatch = AppleWatchSensor(AppleWatchSensor.Config().apply { config in
    config.debug  = true
    config.dbHost = "https://your-aware-server.example.com/index.php"
})

SensorManager.shared.addSensors([appleWatch])
SensorManager.shared.startAllSensors()

// Trigger upload (call this after transferAllData completes)
appleWatch.sync(force: true)
// or upload all registered sensors at once:
SensorManager.shared.syncAllSensors()
```

To schedule automatic periodic uploads use `DbSyncManager`:

```swift
let syncManager = DbSyncManager.Builder()
    .setInterval(15)  // every 15 minutes
    .build()
syncManager.start()
```

Fine-grained control per table via `DbSyncConfig`:

```swift
appleWatch.dbEngine?.startSync(DbSyncConfig().apply { config in
    config.batchSize        = 1000
    config.removeAfterSync  = true   // delete local records after successful upload
    config.debug            = true
    config.completionHandler = { success, error in
        print("Sync finished — success: \(success)")
    }
})
```

## Related Links

- [WatchConnectivity | Apple Developer Documentation](https://developer.apple.com/documentation/watchconnectivity)
- [WCSession | Apple Developer Documentation](https://developer.apple.com/documentation/watchconnectivity/wcsession)
- [HealthKit | Apple Developer Documentation](https://developer.apple.com/documentation/healthkit)
- [HKWorkoutSession | Apple Developer Documentation](https://developer.apple.com/documentation/healthkit/hkworkoutsession)
- [Core Motion | Apple Developer Documentation](https://developer.apple.com/documentation/coremotion)
- [AVAudioSession | Apple Developer Documentation](https://developer.apple.com/documentation/avfaudio/avaudiosession)
- [SoundAnalysis | Apple Developer Documentation](https://developer.apple.com/documentation/soundanalysis)
- [Core Bluetooth | Apple Developer Documentation](https://developer.apple.com/documentation/corebluetooth)
- [Core Location | Apple Developer Documentation](https://developer.apple.com/documentation/corelocation)
- [WatchKit | Apple Developer Documentation](https://developer.apple.com/documentation/watchkit)

## Author

Yuuki Nishiyama (The University of Tokyo), nishiyama@csis.u-tokyo.ac.jp

## License

`com.awareframework.ios.sensor.applewatch` is available under the Apache License 2.0. See the LICENSE file for more info.


## Citation
If this framework hope your research projects, please cite the following paper.

```
@inproceedings{10.1145/3594739.3612874,
    title = {Smartwatch-Based Sensing Framework for Continuous Data Collection: Design and Implementation},
    author = {Yuuki Nishiyama and Kaoru Sezaki},
    doi = {10.1145/3594739.3612874},
    isbn = {9798400702006},
    year = {2023},
    date = {2023-10-08},
    urldate = {2023-10-08},
    booktitle = {Adjunct Proceedings of the 2023 ACM International Joint Conference on Pervasive and Ubiquitous Computing & the 2023 ACM International Symposium on Wearable Computing},
    pages = {620–625},
    publisher = {Association for Computing Machinery},
    address = {Cancun, Quintana Roo, Mexico},
    series = {UbiComp/ISWC '23 Adjunct},
    tppubtype = {inproceedings}
}
```
