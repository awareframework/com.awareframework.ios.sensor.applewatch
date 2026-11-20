// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "com.awareframework.ios.sensor.applewatch",
    platforms: [.iOS(.v16), .watchOS(.v8)],
    products: [
        .library(
            name: "com.awareframework.ios.sensor.applewatch",
            targets: [
                "com.awareframework.ios.sensor.applewatch.shared",
                "com.awareframework.ios.sensor.applewatch.iOS",
                "com.awareframework.ios.sensor.applewatch.watchOS"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/awareframework/com.awareframework.ios.core.git", from: "1.6.3"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.3.0"),
        // AWUWBData: UWB rows recorded on the watch (AWUWBSensor) and received on the iPhone
        .package(url: "https://github.com/awareframework/com.awareframework.ios.sensor.uwb.git", from: "1.6.1"),
    ],
    targets: [
        // プラットフォーム間共有実装
        .target(
            name: "com.awareframework.ios.sensor.applewatch.shared",
            dependencies: [
                .product(name: "com.awareframework.ios.core", package: "com.awareframework.ios.core"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/com.awareframework.ios.sensor.applewatch/shared"
        ),
        // iOS専用ターゲット
        .target(
            name: "com.awareframework.ios.sensor.applewatch.iOS",
            dependencies: [
                .product(name: "com.awareframework.ios.core", package: "com.awareframework.ios.core"),
                "com.awareframework.ios.sensor.applewatch.shared",  // shared依存を追加
                .product(name: "com.awareframework.ios.sensor.uwb", package: "com.awareframework.ios.sensor.uwb")
            ],
            path: "Sources/com.awareframework.ios.sensor.applewatch/ios"
        ),
        // watchOS専用ターゲット
        .target(
            name: "com.awareframework.ios.sensor.applewatch.watchOS",
            dependencies: [
                .product(name: "com.awareframework.ios.core", package: "com.awareframework.ios.core"),
                "com.awareframework.ios.sensor.applewatch.shared",  // shared依存を追加
            ],
            path: "Sources/com.awareframework.ios.sensor.applewatch/watchos"
        ),
        .testTarget(
            name: "com.awareframework.ios.sensor.applewatchTests",
            dependencies: [
                "com.awareframework.ios.sensor.applewatch.shared",
                "com.awareframework.ios.sensor.applewatch.iOS",
                "com.awareframework.ios.sensor.applewatch.watchOS",
                .product(name: "com.awareframework.ios.sensor.uwb", package: "com.awareframework.ios.sensor.uwb")
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
