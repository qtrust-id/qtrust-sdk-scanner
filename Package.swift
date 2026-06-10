// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QTrustScanner",
    // iOS is the shipping target. macOS is declared only so the platform-agnostic
    // value types (ScanType, ScanResult, ScannerError, ScannerConfig) compile and
    // their tests run on the host via `swift test`; the UIKit/WebView layer stays
    // #if os(iOS)-gated.
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "QTrustScanner", targets: ["QTrustScanner"]),
    ],
    targets: [
        .target(
            name: "QTrustScanner",
            dependencies: [],
            path: "Sources/Scanner",
            // Bundled scanner web page (offline-capable). Single source of truth
            // is cloud/web; kept in sync by scripts/sync-web-assets.sh.
            resources: [.copy("Resources/web")]
        ),
        .testTarget(
            name: "QTrustScannerTests",
            dependencies: ["QTrustScanner"],
            path: "Tests/ScannerTests"
        ),
    ]
)
