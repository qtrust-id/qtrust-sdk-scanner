// swift-tools-version: 5.9
import PackageDescription

// GENERATED — release 1.0.0. Source manifest lives on main branch.
let package = Package(
    name: "QTrustScanner",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "QTrustScanner", targets: ["QTrustScanner"]),
    ],
    targets: [
        .binaryTarget(
            name: "QTrustScanner",
            url: "https://github.com/syahfei-venturo/sdk-ios/releases/download/1.0.0/QTrustScanner-1.0.0.xcframework.zip",
            checksum: "6c3fda521da0a81da3f45986d61f7dcb977aa5b4619134734835a808b7c43c72"
        ),
    ]
)
