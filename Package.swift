// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

let swiftSettings:[SwiftSetting] = [ .define("APPLE_CORE_DATA") ]
//let targets:[String] = [ "MIOCoreData" ]

// NO CORE DATA SUPPORT
//let swiftSettings:[SwiftSetting] = []
//let targets:[String] = [ "MIOCoreData", "CoreDataSwift" ]


let package = Package(
    name: "MIOCoreData",
    platforms: [
        .iOS( .v13),
        .macOS(.v10_15),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "MIOCoreData",
            targets: ["MIOCoreData"]
        ),
        .library(
            name: "CoreDataSwift",
            targets: ["MIOCoreData"]
        ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package( url: "https://github.com/miolabs/MIOCore.git", branch:"master" ),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "MIOCoreData",
            dependencies: ["MIOCore", "CoreDataSwift"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "CoreDataSwift",
            dependencies: ["MIOCore"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "MIOCoreDataTests",
            dependencies: ["MIOCoreData"]),
        .testTarget(
            name: "AppleCoreDataTests"
        ),
    ]
)
