// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

//var swift_settings:[SwiftSetting]? = [ .define( "APPLE_CORE_DATA" ) ]

var products:[Product] = [
    .library(name: "CoreDataSwift", targets: ["CoreDataSwift"]),
    .library(name: "MIOCoreData", targets: ["MIOCoreData"]),
]

var targets:[Target] = [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    .executableTarget(
        name: "ModelBuilder",
        dependencies: [
            .product( name: "ArgumentParser", package: "swift-argument-parser" )
        ]
    ),
    .target(
        name: "CoreDataSwift",
        dependencies: ["MIOCore"]
    ),
    .target(
        name: "MIOCoreData",
        dependencies: ["MIOCore", "CoreDataSwift"]
    ),
    .testTarget(
        name: "MIOCoreDataTests",
        dependencies: ["MIOCoreData"]),
    .testTarget(
        name: "AppleCoreDataTests"
    )
]

if ( ProcessInfo.processInfo.environment["BUILD_PLUGIN"]?.lowercased() == "true" ) == false {
    products.append( .plugin(name: "ModelBuilderPlugin", targets: ["ModelBuilderPlugin"]) )
    targets.append( .plugin(name: "ModelBuilderPlugin", capability: .buildTool(), dependencies: ["model-builder"]) )
    
#if os(Linux)
    targets.append( .binaryTarget( name: "model-builder",
                                    url: "https://github.com/miolabs/MIOCoreData/releases/download/v1.0.0/model-builder.artifactbundle.zip",
                               checksum: "c47c3202ae4f33f4f9bd2f1e182f51cb4607e90ebb6d13e563d20bccd8a04e2b" ) )
#else
    targets.append( .binaryTarget( name: "model-builder", path: "Binaries/model-builder.artifactbundle" ) )
#endif
    
}

let package = Package(
    name: "MIOCoreData",
    platforms: [
        .iOS( .v13),
        .macOS(.v12),
    ],
    products: products,
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package( url: "https://github.com/miolabs/MIOCore.git", branch:"master" ),
        .package( url: "https://github.com/apple/swift-argument-parser", from: "1.5.0" ),
    ],
    targets: targets
)
