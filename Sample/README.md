# Scanner SDK Sample App

A minimal SwiftUI sample app demonstrating all three API styles of the Scanner SDK.

## Features

- **Callback API**: `scanner.start(in:, type:, onResult:, onError:)`
- **Stream API**: `for await result in scanner.stream(in:, type:) { }`
- **One-Shot API**: `let result = try await scanner.scan(in:, type:)`
- **QR Code & Barcode** scanning support
- **Real-time result display** with bounding box

## Setup Instructions

### 1. Create Xcode Project

```bash
# Open Xcode and create a new iOS App project named "ScannerSample"
# Select SwiftUI and iOS 15+ as deployment target
```

### 2. Add Scanner SDK as Package Dependency

1. In Xcode: **File > Add Packages**
2. Enter the local path: `../../sdk-ios` (relative to your project)
3. Select **Dependency Rule: Exact** and confirm
4. Add to target: **ScannerSample**

### 3. Copy Sample Files

Copy these files into your Xcode project:

- `ScannerSampleApp.swift` → App entry point
- `ContentView.swift` → Main UI with API style selection
- `ScannerScreen.swift` → Full-screen scanner with three API styles
- `ResultView.swift` → Result display and clipboard copy

### 4. Configure App Permissions

Add to `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan QR codes and barcodes</string>
```

Or in Xcode:
1. Select project > Target > Info
2. Add key: `Privacy - Camera Usage Description`
3. Value: `This app needs camera access to scan QR codes and barcodes`

### 5. Configure API Key

In `ContentView.swift`, replace the placeholder:

```swift
private let apiKey = "sk_live_your_api_key_here"
```

With your actual Scanner SDK API key from the qtrust dashboard.

### 6. Run on Device

- Build and run on a physical iOS device (camera required)
- Select a scan type (QR or Barcode)
- Choose an API style to see how each one works
- Grant camera permissions when prompted

## API Style Comparison

### Callback Style
```swift
scanner.start(
    in: scannerView,
    type: .qr,
    onResult: { result in print(result.data) },
    onError: { error in print(error) }
)
```
**Best for**: Simple flows where you need one scan result

### Stream Style
```swift
Task {
    for try await result in scanner.stream(in: scannerView, type: .barcode) {
        print(result.data)
    }
}
```
**Best for**: Continuous scanning or multiple results

### One-Shot Style
```swift
Task {
    let result = try await scanner.scan(in: scannerView, type: .qr)
    print(result.data)
}
```
**Best for**: Modern async/await code, single result expected

## Project Structure

```
sdk-ios/Sample/
├── README.md                    # This file
├── ScannerSampleApp.swift       # @main entry point
├── ContentView.swift            # Main view with API style selection
├── ScannerScreen.swift          # Full-screen scanner implementation
└── ResultView.swift             # Result display component
```

## Result Display

After a successful scan, the app shows:

- **Data**: The decoded content (copyable)
- **Format**: The barcode/QR format
- **Bounding Box**: Location and size of scan in the view

## Troubleshooting

### Camera Permission Denied
- Check Info.plist has `NSCameraUsageDescription`
- Go to Settings > ScannerSample > Camera and enable

### Scanner Not Starting
- Ensure API key is valid in `ContentView.swift`
- Run on a physical device (simulator camera is limited)
- Check network connectivity

### Build Errors
- Verify Scanner package is added as dependency
- Clean build folder: **Cmd+Shift+K**
- Re-add package if needed

## Next Steps

- Integrate into your production app
- Replace the test API key with your actual key
- Customize result handling and UI
- Add error recovery and retry logic

## Support

For issues with the Scanner SDK, see the main README at `sdk-ios/README.md`.
