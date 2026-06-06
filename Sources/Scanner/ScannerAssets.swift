#if os(iOS)
import Foundation

/// Locations of the offline scanner web assets bundled inside the SDK.
///
/// The scanner UI ships as a single, self-contained web bundle so it loads from
/// a `file://` origin (a secure context in `WKWebView`, required for
/// `getUserMedia`). The page is a classic-script bundle (no ES modules), because
/// `WKWebView` blocks ES-module and `file://` resource loading; the on-device
/// zxing decoder and its wasm are inlined, so scanning works fully offline.
///
/// Hosts that drive their own `WKWebView` — instead of using `Scanner`/
/// `ScannerView` — load `indexURL` with read access to `webDirectoryURL`.
/// Scanning is fully on-device; no network or server URL is involved.
public enum ScannerAssets {
    /// Directory holding the bundled web assets. Pass to
    /// `WKWebView.loadFileURL(_:allowingReadAccessTo:)`. `nil` only if the bundle
    /// is missing from the SDK resources.
    public static var webDirectoryURL: URL? {
        Bundle.module.url(forResource: "web", withExtension: nil)
    }

    /// The `index.html` entry point. `nil` if the bundle is missing.
    public static var indexURL: URL? {
        webDirectoryURL?.appendingPathComponent("index.html")
    }
}
#endif
