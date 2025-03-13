// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "com.awareframework.ios.sensor.applewatch",
    platforms: [.iOS(.v13), .watchOS(.v8)],
    products: [
        .library(
            name: "com.awareframework.ios.sensor.applewatch",
            targets: [
                "com.awareframework.ios.sensor.applewatch"
            ]
        ),        // .library(
        //     name: "com.awareframework.ios.sensor.applewatch_ios",
        //     targets: [
        //         "com.awareframework.ios.sensor.applewatch_ios"
        //     ]
        // ),
        // .library(
        //     name: "com.awareframework.ios.sensor.applewatch_watchos",
        //     targets: [
        //         "com.awareframework.ios.sensor.applewatch_watchos"
        //     ]
        // )
    ],
    dependencies: [
        .package(url: "git@github.com:awareframework/com.awareframework.ios.sensor.core.git", from: "0.7.7"),
        .package(url: "git@github.com:mw99/DataCompression.git", from: "3.8.0")
    ],
    targets: [
        .target(
            name: "com.awareframework.ios.sensor.applewatch",
            dependencies: [
                .product(name: "com.awareframework.ios.sensor.core", package: "com.awareframework.ios.sensor.core", condition: .when(platforms: [.iOS])),
                .product(name: "DataCompression", package: "DataCompression")
            ],
            path: "com.awareframework.ios.sensor.applewatch/Classes",
            sources: ["watchos", "ios"]
        )
    ],
    swiftLanguageModes: [.v5]
)
