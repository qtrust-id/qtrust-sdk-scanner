// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QTrustScanner",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "QTrustScanner", targets: ["QTrustScanner"]),
    ],
    targets: [
        .target(
            name: "QTrustScanner",
            dependencies: [],
            path: "Sources/Scanner"
        ),
        .testTarget(
            name: "QTrustScannerTests",
            dependencies: ["QTrustScanner"],
            path: "Tests/ScannerTests"
        ),
    ]
)
