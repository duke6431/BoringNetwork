// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BoringNetwork",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "BoringNetwork",
            targets: ["BoringNetwork"]
        ),
        .library(
            name: "AsyncBoringNetwork",
            targets: ["AsyncBoringNetwork"]
        ),
        .library(
            name: "ReactiveBoringNetwork",
            targets: ["ReactiveBoringNetwork"]
        ),
        
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveX/RxSwift", .upToNextMajor(from: "6.0.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "BoringNetwork"
        ),
        .target(
            name: "AsyncBoringNetwork",
            dependencies: [
                .target(name: "BoringNetwork"),
            ]
        ),
        .target(
            name: "ReactiveBoringNetwork",
            dependencies: [
                .target(name: "BoringNetwork"),
                "RxSwift"
            ]
        ),
        .testTarget(
            name: "BoringNetworkTests",
            dependencies: ["BoringNetwork"]
        ),
    ]
)
