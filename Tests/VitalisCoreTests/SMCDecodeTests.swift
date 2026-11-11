import XCTest
@testable import VitalisCore

final class SMCDecodeTests: XCTestCase {
    func testFloatIsLittleEndian() {
        XCTAssertEqual(SMCDecode.value(type: "flt ", bytes: [0x00, 0x00, 0x48, 0x42]), 50.0)
    }

    func testUnsignedIntegersAreBigEndian() {
        XCTAssertEqual(SMCDecode.value(type: "ui8 ", bytes: [3]), 3)
        XCTAssertEqual(SMCDecode.value(type: "ui16", bytes: [0x04, 0xB0]), 1200)
        XCTAssertEqual(SMCDecode.value(type: "ui32", bytes: [0, 0, 0x04, 0xB0]), 1200)
    }

    func testFixedPoint() {
        XCTAssertEqual(SMCDecode.value(type: "fpe2", bytes: [0x12, 0xC0]), 1200)
        XCTAssertEqual(SMCDecode.value(type: "sp78", bytes: [0x32, 0x80]), 50.5)
        XCTAssertEqual(SMCDecode.value(type: "sp78", bytes: [0xFF, 0x00]), -1)
    }

    func testUnknownTypeIsNil() {
        XCTAssertNil(SMCDecode.value(type: "ch8*", bytes: [1, 2]))
    }

    func testTooFewBytesIsNil() {
        XCTAssertNil(SMCDecode.value(type: "flt ", bytes: [0x00, 0x00]))
        XCTAssertNil(SMCDecode.value(type: "ui16", bytes: [0x01]))
        XCTAssertNil(SMCDecode.value(type: "ui8 ", bytes: []))
    }

    func testNotANumberIsNil() {
        XCTAssertNil(SMCDecode.value(type: "flt ", bytes: [0x00, 0x00, 0xC0, 0x7F]))
    }
}
