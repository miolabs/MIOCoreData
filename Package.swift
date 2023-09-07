// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

let swiftSettings: [SwiftSetting]

let cd_env = ( ProcessInfo.processInfo.environment["APPLE_CORE_DATA"] ?? "0" ).lowercased()
let enable_cd = !( cd_env == "0" || cd_env == "false" )
if enable_cd {
    swiftSettings = [ .define("APPLE_CORE_DATA")]
} else {
    swiftSettings = []
}

let package = Package(
    name: "MIOCoreData",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "MIOCoreData",
            targets: ["MIOCoreData"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/miolabs/MIOCore.git", .branch("master") ),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "MIOCoreData",
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
