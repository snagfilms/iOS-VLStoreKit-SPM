// swift-tools-version: 5.8.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VLStoreKit",
    platforms: [
        .iOS(.v14),
        .tvOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "VLStoreKit",
            targets: ["VLStoreKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/snagfilms/iOS-VLBeacon-SPM.git", branch: "main"),
        .package(url: "https://github.com/socketio/socket.io-client-swift.git", branch: "master")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "VLStoreKit",
            dependencies: [
                .product(name: "SocketIO", package: "socket.io-client-swift"),
                .product(name: "VLBeaconLib", package: "iOS-VLBeacon-SPM"),
//                .product(name: "Starscream", package: "Starscream")
            ]),
        .testTarget(
            name: "VLStoreKitTests",
            dependencies: ["VLStoreKit"]),
    ]
)

