#if os(iOS)
import SwiftUI

@available(iOS 15.0, *)
public struct ScannerViewRepresentable: UIViewRepresentable {
    public init() {}
    public func makeUIView(context: Context) -> ScannerView { ScannerView() }
    public func updateUIView(_ uiView: ScannerView, context: Context) {}
}
#endif
