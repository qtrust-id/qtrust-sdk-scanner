import Foundation

public struct ScanResult: Decodable, Sendable {
    public let data: String
    public let format: String
    public let confidence: Double
    public let boundingBox: BoundingBox

    enum CodingKeys: String, CodingKey {
        case data, format, confidence
        case boundingBox = "bounding_box"
    }
}

public struct BoundingBox: Decodable, Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int
}
