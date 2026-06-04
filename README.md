# QTrustScanner — iOS SDK

Cloud-backed QR & barcode scanner for iOS, distributed as a prebuilt
**XCFramework** via Swift Package Manager. Ships an offline-capable scanner web
layer with an on-device decode fallback when the cloud is unreachable.

## Requirements

- iOS 15.0+
- Swift 5.9+ / Xcode 15+
- Camera-capable device (simulator camera is limited)

## Installation

### Swift Package Manager

In Xcode: **File ▸ Add Package Dependencies…**, enter:

```
https://github.com/qtrust-id/qtrust-sdk-scanner.git
```

Pin to **Up to Next Major** from `1.0.4`.

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/qtrust-id/qtrust-sdk-scanner.git", from: "1.0.4"),
],
targets: [
    .target(name: "YourApp", dependencies: ["QTrustScanner"]),
]
```

SwiftPM downloads the XCFramework from the GitHub Release and verifies its
checksum — no local build required.

### Camera Permission

Add to your app's `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera is required to scan QR codes and barcodes</string>
```

## Quick Start

The SDK exposes a `Scanner` driving a `ScannerView`. Three API styles cover the
common flows.

```swift
import QTrustScanner

let scanner = Scanner(config: ScannerConfig(apiKey: "sk_live_xxx"))
let view = ScannerView()   // add to your view hierarchy

// Style 1 — Callback
scanner.start(
    in: view,
    type: .qr,
    onResult: { result in print(result.data, result.format) },
    onError:  { error  in print(error.localizedDescription) }
)

// Style 2 — AsyncStream (continuous)
Task {
    for await result in scanner.stream(in: view, type: .barcode) {
        print(result.data)
    }
}

// Style 3 — async/await (single shot)
Task {
    do {
        let result = try await scanner.scan(in: view, type: .qr)
        print(result.data)
    } catch {
        print(error)
    }
}

// Stop / tear down the callback + stream styles
scanner.stop(view: view)
```

### SwiftUI

Embed the camera surface with `ScannerViewRepresentable`:

```swift
import SwiftUI
import QTrustScanner

struct ScanView: View {
    var body: some View {
        ScannerViewRepresentable()
            .ignoresSafeArea()
    }
}
```

## Configuration

```swift
ScannerConfig(
    apiKey: "sk_live_xxx",
    baseUrl: "https://scan.qtrust.id",   // default
    timeout: 30,                          // seconds, default
    vendorConfig: VendorConfig(
        vendorId: "",
        textHintScan: "",
        theme: .dark,        // .dark | .light
        locale: .id,         // .id | .en
        skipTutorial: true
    )
)
```

## API Reference

### `ScanType`

| Case | Raw | Meaning |
|------|-----|---------|
| `.qr` | 0 | QR codes |
| `.barcode` | 1 | 1D barcodes |

### `ScanResult`

```swift
struct ScanResult {
    let data: String          // decoded content
    let format: String        // e.g. "QR_CODE", "EAN_13"
    let boundingBox: BoundingBox
}

struct BoundingBox { let x, y, width, height: Int }
```

### `ScannerError`

`connectionFailed` · `permissionDenied` · `timeout` · `serverError` — all carry
a message exposed via `errorDescription`.

### `Scanner`

| Method | Style |
|--------|-------|
| `start(in:type:onResult:onError:)` | callback |
| `stream(in:type:)` → `AsyncStream<ScanResult>` | continuous |
| `scan(in:type:)` async throws → `ScanResult` | single shot |
| `stop(view:)` | tear down |

## Example App

A full SwiftUI integration lives in [`Sample/`](Sample/) (depends on the SDK via
local path) and in the monorepo's `example-ios/` (depends on this published
package). See [`Sample/README.md`](Sample/README.md).

## Versioning

Semantic versioning. Release tags carry a thin `binaryTarget` manifest pointing
at the XCFramework zip on the matching GitHub Release. See
[Releases](https://github.com/qtrust-id/qtrust-sdk-scanner/releases).

> `1.0.0`–`1.0.1` are import-broken (missing Swift module). Use **`1.0.4`+**.

## License

Proprietary — © QTrust. Contact the QTrust team for usage terms.
