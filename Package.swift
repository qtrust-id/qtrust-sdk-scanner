// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Scanner",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "Scanner", targets: ["Scanner"]),
    ],
    targets: [
        .target(
            name: "Scanner",
            dependencies: [],
            path: "Sources/Scanner"
        ),
        .testTarget(
            name: "ScannerTests",
            dependencies: ["Scanner"],
            path: "Tests/ScannerTests"
        ),
    ]
)
