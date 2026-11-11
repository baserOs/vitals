import Foundation

/// Turns the raw bytes of an SMC value into a number.
public enum SMCDecode {
    public static func value(type: String, bytes: [UInt8]) -> Double? {
        let result: Double
        switch type {
        case "flt ":
            // Little-endian 32-bit float on Apple Silicon.
            guard bytes.count >= 4 else { return nil }
            let bits = UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
            result = Double(Float(bitPattern: bits))
        case "ui8 ":
            guard bytes.count >= 1 else { return nil }
            result = Double(bytes[0])
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            result = Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
        case "ui32":
            guard bytes.count >= 4 else { return nil }
            let value = (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
            result = Double(value)
        case "fpe2":
            // Unsigned fixed point with 2 fractional bits.
            guard bytes.count >= 2 else { return nil }
            result = Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1])) / 4
        case "sp78":
            // Signed fixed point with 8 fractional bits.
            guard bytes.count >= 2 else { return nil }
            let raw = Int16(bitPattern: (UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
            result = Double(raw) / 256
        default:
            return nil
        }
        return result.isFinite ? result : nil
    }
}
