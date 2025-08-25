// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "JSONFormatterFeature",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "JSONFormatterFeature",
            targets: ["JSONFormatterFeature"]
        ),
        .executable(
            name: "JSONFormatterApp",
            targets: ["JSONFormatterApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/hmlongco/Factory", from: "2.3.0"),
        .package(url: "https://github.com/ZeeZide/CodeEditor.git", from: "1.2.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0")
    ],
    targets: [
        .target(
            name: "JSONFormatterFeature",
            dependencies: [
                "Factory",
                .product(name: "CodeEditor", package: "CodeEditor")
            ]
        ),
        .executableTarget(
            name: "JSONFormatterApp",
            dependencies: ["JSONFormatterFeature"]
        ),
        .testTarget(
            name: "JSONFormatterFeatureTests",
            dependencies: [
                "JSONFormatterFeature",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ]
        ),
    ]
)
