# AWARE: AppleWatch

[![License](https://github.com/tetujin/com.awareframework.ios.sensor.applewatch/blob/main/LICENSE)](LICENSE)

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


## Installation

You can integrate this framework into your project via Swift Package Manager (SwiftPM).

### SwiftPM
1. Open Package Manager Windows
    * Open `Xcode` -> Select `Menu Bar` -> `File` -> `App Package Dependencies...` 

2. Find the package using the manager
    * Select `Search Package URL` and type `https://github.com/tetujin/com.awareframework.ios.sensor.applewatch.git`

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


## Development
The following source code shows a minimum sample code for collecting sensor data on a smartwatch. A developer has to write source codes on both iOS and wathcOS as follows.

### iOS
```swift
import com_awareframework_ios_sensor_core
import com_awareframework_ios_sensor_applewatch
```

```swift
let appleWatch = AppleWatchSensor(AppleWatchSensor.Config().apply{config in
    config.debug = true
})

SensorManager.shared.addSensors([appleWatch])
SensorManager.shared.startAllSensors()
```

More detailed sample codes can be found [here](https://github.com/tetujin/com.awareframework.ios.sensor.applewatch/blob/d16646411f5caf89d19797a187fe5c489d93f2eb/Example/com.awareframework.ios.sensor.applewatch/AppDelegate.swift#L30).


### watchOS

```swift
import com_awareframework_ios_sensor_applewatch
```

```swift
let motionSensor = AWMotionSensor.shared.start(AWMotionSensor.Config().apply{config in
    config.motionSensorHz = 50
    config.debug = true
})
motionSensor.start()

AWSensorManager.shared.set(sensors: [motionSensor])

// Transfer all locally stored sensor data to the paired iPhone.
AWSensorManager.shared.transferAllData { error in
    if let error { print("Transfer failed: \(error)") }
}
```
More detailed sample codes can be found [here](https://github.com/tetujin/com.awareframework.ios.sensor.applewatch/blob/909f71e0aadc2c05cfa0fb7f21e5584ebb095620/Example/AwareWatch%20Watch%20App/ContentView.swift#L31).


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

### Configuration

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `recordsPerChunk` | `Int` | `500` | Number of sensor records packed into each compressed chunk |
| `useColumnarFormat` | `Bool` | `true` | Encode JSON in columnar format (smaller payload) |
| `debug` | `Bool` | `false` | Print verbose progress logs to the console |

```swift
AWDataTransferManager.shared.recordsPerChunk = 1000
AWDataTransferManager.shared.useColumnarFormat = true
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
// Start a transfer (skipped if one is already in progress)
AWDataTransferManager.shared.transferData(sensors: sensors) { error in
    // called on main thread when all transfers finish or fail
}

// Convenience wrapper via AWSensorManager
AWSensorManager.shared.transferAllData { error in … }

// Cancel all in-flight transfers
AWDataTransferManager.shared.cancel()
```

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

