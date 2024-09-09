// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

//var swift_settings:[SwiftSetting]? = [ .define( "APPLE_CORE_DATA" ) ]
#if os(Linux)
let binary_target = Target.binaryTarget( name: "model-builder",
                                         url: "https://github.com/miolabs/MIOCoreData/releases/download/v1.0.5/model-builder.artifactbundle.zip",
                                         checksum: "3cbada33032de1aad58a50774c342addf5d857eb24a1c6dc7dcf3b6fe540054e" )
#else
let binary_target = Target.binaryTarget( name: "model-builder", path: "Binaries/model-builder.artifactbundle" )
#endif

let package = Package(
    name: "MIOCoreData",
    platforms: [
        .iOS( .v13),
        .macOS(.v12),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library( name: "CoreDataSwift", targets: ["MIOCoreData"] ),
        .library( name: "MIOCoreData", targets: ["MIOCoreData"] ),
        .plugin( name: "ModelBuilderPlugin", targets: ["ModelBuilderPlugin"] ),
  //      .executable( name: "ModelBuilder", targets: ["ModelBuilder"] )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package( url: "https://github.com/miolabs/MIOCore.git", branch:"master" ),
        .package( url: "https://github.com/apple/swift-argument-parser", from: "1.5.0" ),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .executableTarget(
            name: "ModelBuilder",
            dependencies: [
                .product( name: "ArgumentParser", package: "swift-argument-parser" )
            ]
        ),
        .plugin(
            name: "ModelBuilderPlugin",
            capability: .buildTool(),
            dependencies: [ "model-builder" ]
        ),
        binary_target,
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
        ),
    ]
)
