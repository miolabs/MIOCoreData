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
        .package(url: "https://github.com/miolabs/MIOCoreDataTools.git", branch: "main")
    ],
    targets: [
        .target(
            name: "CoreDataSwift",
            dependencies: [
                .product(name: "MIOCore", package: "MIOCore"),
                .product(name: "MIOCoreLogger", package: "MIOCore"),
            ]
        ),
        .target(
            name: "MIOCoreData",
            dependencies: [
                "CoreDataSwift",
                .product(name: "MIOCore", package: "MIOCore"),
                .product(name: "MIOCoreLogger", package: "MIOCore"),
            ]
    //        swiftSettings: [ .define( "APPLE_CORE_DATA" ) ]
        ),
        .target(
            name: "TestModel",
            dependencies: ["MIOCoreData"],
            path: "Tests/TestModel",
            plugins: [ .plugin( name: "ModelBuilderPlugin", package: "MIOCoreDataTools" ) ]
        ),
        .testTarget(
            name: "MIOCoreDataTests",
            dependencies: ["MIOCoreData", "TestModel"]
        ),
        .testTarget(
            name: "AppleCoreDataTests"
        )
    ]
)
