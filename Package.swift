// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MIOCoreData",
    platforms: [
        .iOS( .v13),
        .macOS(.v12),
    ],
    products: [
        .library(name: "CoreDataSwift", targets: ["CoreDataSwift"]),
        .library(name: "MIOCoreData", targets: ["MIOCoreData"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package( url: "https://github.com/miolabs/MIOCore.git", branch:"master" ),
        .package( url: "https://github.com/apple/swift-argument-parser", from: "1.5.0" ),
    ],
    targets: [
        .target(
            name: "CoreDataSwift",
            dependencies: ["MIOCore"]
        ),
        .target(
            name: "MIOCoreData",
            dependencies: ["MIOCore", "CoreDataSwift"]
    //        swiftSettings: [ .define( "APPLE_CORE_DATA" ) ]
        ),
        .testTarget(
            name: "MIOCoreDataTests",
            dependencies: ["MIOCoreData"]),
        .testTarget(
            name: "AppleCoreDataTests"
        )
    ]
)
