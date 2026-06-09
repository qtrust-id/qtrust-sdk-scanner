import Foundation

public enum ScanType: Int, Sendable {
    /// QR codes (QR, Micro QR).
    case qr = 0
    /// Linear 1D barcodes (EAN, UPC, Code128, Code39, Codabar, ITF).
    case barcode = 1
    /// PDF417 stacked linear barcodes.
    case pdf417 = 2
    /// Aztec 2D codes.
    case aztec = 3
    /// Data Matrix 2D codes.
    case dataMatrix = 4
}
