# com.awareframework.ios.sensor.applewatch

[![CI Status](https://img.shields.io/travis/1227623/com.awareframework.ios.sensor.applewatch.svg?style=flat)](https://travis-ci.org/1227623/com.awareframework.ios.sensor.applewatch)
[![Version](https://img.shields.io/cocoapods/v/com.awareframework.ios.sensor.applewatch.svg?style=flat)](https://cocoapods.org/pods/com.awareframework.ios.sensor.applewatch)
[![License](https://img.shields.io/cocoapods/l/com.awareframework.ios.sensor.applewatch.svg?style=flat)](https://cocoapods.org/pods/com.awareframework.ios.sensor.applewatch)
[![Platform](https://img.shields.io/cocoapods/p/com.awareframework.ios.sensor.applewatch.svg?style=flat)](https://cocoapods.org/pods/com.awareframework.ios.sensor.applewatch)

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
    * Conversation
    * Ambient noise
* Heatrate

### Screenshots
![main_screen](/images/screenshots/main.jpeg)
![sensor_settings](/images/screenshots/sensors.jpeg)
![conversation](/images/screenshots/conversation.jpeg)
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
"[Smartwatch-Based Sensing Framework for Continuous Data Collection: Design and Implementation](https://dl.acm.org/doi/10.1145/3594739.3612874)," Y. Nishiyama and K. Sezaki, UbiComp2023 Workshop (Sensing & Intervention)

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

You can integrate this framework into your project via CocoaPods.

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

### CocoaPods with <u>a public repository</u>

__NOTE: This installing method is not supported yet!!!__

`com.awareframework.ios.sensor.applewatch` is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'com.awareframework.ios.sensor.applewatch'
```

<!-- 
### Swift Packages
TBD 
-->


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

## Author

Yuuki Nishiyama (The University of Tokyo), yuukin@iis.u-tokyo.ac.jp

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

