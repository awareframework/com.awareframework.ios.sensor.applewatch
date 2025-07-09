# AWARE: AppleWatch

[![License](https://github.com/tetujin/com.awareframework.ios.sensor.applewatch/blob/main/LICENSE)](LICENSE)

## Overview
**AWARE-watchOS** is a passive wearable sensing framework for watchOS. This framework allows us to continually collect multiple sensor data on smartwatches with a minimum workload. Especially, this framework collects eight sensors on the smartwatch and transfers the collected data as a compressed CSV file every few minutes (by default, five minutes). The transferred files are managed on an eco-system of the AWARE framework. Moreover, as an option, data in transferred files can be stored or streamed in the paired smartphone application.

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
The following figure illustrates the design of this framework. This framework is composed of two major components: watchOS and iOS side. During data collection, the watchOS-side component runs as an exercise application to collect data in the background. Moreover, watchOS saves the collected data as a CSV file or audio file (MP3 or WAV) and transfers the files to the iOS side via a file transfer protocol (`WatchConnectivity`) on iOS and watchOS.

![design](/images/aware-watch.png)

### Battery consumption
Battery consumption is dependent on the types and settings of sensors. 
Our lab study shows that this framework works for 16 to 29 hours with single sensors. High-sampling rate and more extensive data size generated sensors tend to consume battery. 

![battery_consumption](/images/battery_full.png)

For more detailes, please check out the paper as follows:
"[Smartwatch-Based Sensing Framework for Continuous Data Collection: Design and Implementation](https://dl.acm.org/doi/10.1145/3594739.3612874)," Y. Nishiyama and K. Sezaki, UbiComp2023 Workshop (Mental Health: Sensing & Intervention)

## Run an example application
To run the example project, clone the repo and run `pod install` from the Example directory first.

For example: 
1. Download the project by following the command on your terminal.
    ```shell
    git clone https://www.github.com/tetujin/com.awareframework.ios.sensor.applewatch
    ```
2. Change the directory to `Example` directory in the downloaded project.
    ```shell
    cd com.awareframework.ios.sensor.applewatch/Example
    ```
3. Run `pod install` on the `Example` directory.
4. Open `com.awareframework.ios.sensor.applewatch.xcworkspace` by Xcode
5. Run the project with your target iOS and watchOS installed devices (including iOS and watchOS simulators).


## Installation

You can integrate this framework into your project via Swift Package Manager (SwiftPM) or CocoaPods.

### SwiftPM
1. Open Package Manager Windows
    * Open `Xcode` -> Select `Menu Bar` -> `File` -> `App Package Dependencies...` 

2. Find the package using the manager
    * Select `Search Package URL` and type `git@github.com:tetujin/com.awareframework.ios.sensor.applewatch.git`

3. Import package both `iOS` and `watchOS` targets.


### CocoaPods with <u>GitHub</u>
[CocoaPods](https://cocoapods.org) is a defact standard library manager for iOS application development. By using this library manager, you can download and install this library from GitHub. Before executing the following steps, please install and setup the CococaPod environment.

1. Run `pod init` to set CocoaPod environment.
```shell
pod init
```

2. Edit `Podfile` like following codes to install `com.awareframework.ios.sensor.applewatch` into your project.
```ruby
target '[TARGET_NAME]' do
  use_frameworks!
  pod 'com.awareframework.ios.sensor.applewatch', :git => 'git@github.com:tetujin/com.awareframework.ios.sensor.applewatch.git'
end

target '[TARGET_NAME_FOR_WATCH_APP]' do
  use_frameworks!
  pod 'com.awareframework.ios.sensor.applewatch', :git => 'git@github.com:tetujin/com.awareframework.ios.sensor.applewatch.git'
end

```

3. Execute `pod install` on your project
```shell
pod install
```

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
    config.dbType = .REALM
    config.keepOriginalFileFromWatch = true
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
AWSensor.shared.start(AWSensorConfig().apply{config in
    config.motionSensorHz = 50
    config.activateMotionSensor = true
})
```
More detailed sample codes can be found [here](https://github.com/tetujin/com.awareframework.ios.sensor.applewatch/blob/909f71e0aadc2c05cfa0fb7f21e5584ebb095620/Example/AwareWatch%20Watch%20App/ContentView.swift#L31).

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

