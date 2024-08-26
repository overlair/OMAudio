// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OMAudio",
    platforms: [
        .iOS("13.0"),
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OMAudio",
            targets: ["OMAudio"]),
    ],
    dependencies: [
            .package(url: "https://github.com/AudioKit/AudioKit.git", from: "5.6.2"),
            .package(url: "https://github.com/AudioKit/SporthAudioKit.git", from: "5.3.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "OMAudio",
            dependencies: [
                .product(name: "AudioKit", package: "AudioKit"),
                .product(name: "SporthAudioKit", package: "SporthAudioKit"),
            ]),
        .testTarget(
            name: "OMAudioTests",
            dependencies: ["OMAudio"]),
    ]
)
