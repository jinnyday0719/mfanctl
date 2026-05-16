import Foundation

public struct SMCValue: Sendable {
    public let key: String
    public let dataType: String
    public let dataSize: UInt32
    public let resultCode: UInt8
    public let bytes: [UInt8]

    public init(key: String, dataType: String, dataSize: UInt32, resultCode: UInt8 = 0, bytes: [UInt8]) {
        self.key = key
        self.dataType = dataType
        self.dataSize = dataSize
        self.resultCode = resultCode
        self.bytes = bytes
    }

    public var numericValue: Double? {
        guard dataSize > 0 else {
            return nil
        }

        switch dataType {
        case "ui8 ":
            return Double(bytes[safe: 0] ?? 0)
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "ui32":
            guard bytes.count >= 4 else { return nil }
            return Double(
                UInt32(bytes[0]) << 24 |
                UInt32(bytes[1]) << 16 |
                UInt32(bytes[2]) << 8 |
                UInt32(bytes[3])
            )
        case "sp1e":
            return fixedPoint(divisor: 16_384)
        case "sp3c":
            return fixedPoint(divisor: 4_096)
        case "sp4b":
            return fixedPoint(divisor: 2_048)
        case "sp5a":
            return fixedPoint(divisor: 1_024)
        case "sp69":
            return fixedPoint(divisor: 512)
        case "sp78":
            return fixedPoint(divisor: 256)
        case "sp87":
            return fixedPoint(divisor: 128)
        case "sp96":
            return fixedPoint(divisor: 64)
        case "spa5":
            return fixedPoint(divisor: 32)
        case "spb4":
            return fixedPoint(divisor: 16)
        case "spf0":
            return fixedPoint(divisor: 1)
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            let value = bytes.prefix(4).withUnsafeBytes { rawBuffer in
                rawBuffer.load(as: Float.self)
            }
            guard value.isFinite else { return nil }
            return Double(value)
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            return Double((Int(bytes[0]) << 6) + (Int(bytes[1]) >> 2))
        default:
            return nil
        }
    }

    private func fixedPoint(divisor: Double) -> Double? {
        guard bytes.count >= 2 else { return nil }
        let raw = Int(bytes[0]) * 256 + Int(bytes[1])
        return Double(raw) / divisor
    }
}

private extension Array where Element == UInt8 {
    subscript(safe index: Int) -> UInt8? {
        indices.contains(index) ? self[index] : nil
    }
}
