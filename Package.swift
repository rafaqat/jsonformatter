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
        ),
        .executable(
            name: "TestRunner",
            targets: ["TestRunner"]
        ),
        .executable(
            name: "BracketTest",
            targets: ["BracketTest"]
        ),
        .executable(
            name: "MultipleObjectsTest",
            targets: ["MultipleObjectsTest"]
        ),
        .executable(
            name: "UnicodeTest",
            targets: ["UnicodeTest"]
        ),
        .executable(
            name: "ExtendedTestRunner",
            targets: ["ExtendedTestRunner"]
        ),
        .executable(
            name: "EnhancedTestRunner",
            targets: ["EnhancedTestRunner"]
        ),
        .executable(
            name: "ComprehensiveTestRunner",
            targets: ["ComprehensiveTestRunner"]
        ),
        .executable(
            name: "QuickTest",
            targets: ["QuickTest"]
        ),
        .executable(
            name: "SerialTestRunner",
            targets: ["SerialTestRunner"]
        ),
        .executable(
            name: "SyncTestRunner",
            targets: ["SyncTestRunner"]
        ),
        .executable(
            name: "MinimalTest",
            targets: ["MinimalTest"]
        ),
        .executable(
            name: "ParserTestSuite",
            targets: ["ParserTestSuite"]
        ),
        .executable(
            name: "SimpleParserTest",
            targets: ["SimpleParserTest"]
        ),
        .executable(
            name: "DebugParserTest",
            targets: ["DebugParserTest"]
        ),
        .executable(
            name: "QuickParserTest",
            targets: ["QuickParserTest"]
        ),
        .executable(
            name: "FinalParserTest",
            targets: ["FinalParserTest"]
        ),
        .executable(
            name: "ImprovedParserTest",
            targets: ["ImprovedParserTest"]
        ),
        .executable(
            name: "DiagnosticTest",
            targets: ["DiagnosticTest"]
        ),
        .executable(
            name: "VerifyTest",
            targets: ["VerifyTest"]
        ),
        .executable(
            name: "FixValidationTest",
            targets: ["FixValidationTest"]
        ),
        .executable(
            name: "FailureAnalysis",
            targets: ["FailureAnalysis"]
        ),
        .executable(
            name: "RegressionTest",
            targets: ["RegressionTest"]
        ),
        .executable(
            name: "SurrogatePairTest",
            targets: ["SurrogatePairTest"]
        ),
        .executable(
            name: "SurrogateFixTest",
            targets: ["SurrogateFixTest"]
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
        .executableTarget(
            name: "TestRunner",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "BracketTest",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "MultipleObjectsTest",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "UnicodeTest",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "ExtendedTestRunner",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "EnhancedTestRunner",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "ComprehensiveTestRunner",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "QuickTest",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "SerialTestRunner",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "SyncTestRunner",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "MinimalTest",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "ParserTestSuite",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "SimpleParserTest",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "DebugParserTest",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "QuickParserTest",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "FinalParserTest",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "ImprovedParserTest",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "DiagnosticTest",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "VerifyTest",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "FixValidationTest",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "FailureAnalysis",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "RegressionTest",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "SurrogatePairTest",
            dependencies: ["JSONFormatterFeature"]
        ),
        .executableTarget(
            name: "SurrogateFixTest",
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
