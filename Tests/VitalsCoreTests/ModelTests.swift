import XCTest
@testable import VitalsCore

final class FanReadingTests: XCTestCase {
    // Review Focus 2: MacBook Pro fans stop when idle, below their minimum.
    func testStoppedFanIsZero() {
        XCTAssertEqual(FanReading(id: 0, rpm: 0, minRPM: 1200, maxRPM: 6000).fraction, 0)
    }

    func testFractionBetweenMinimumAndMaximum() {
        XCTAssertEqual(FanReading(id: 0, rpm: 3600, minRPM: 1200, maxRPM: 6000).fraction, 0.5)
    }

    func testAboveMaximumIsOne() {
        XCTAssertEqual(FanReading(id: 0, rpm: 7000, minRPM: 1200, maxRPM: 6000).fraction, 1)
    }

    func testNoReportedRangeIsZero() {
        XCTAssertEqual(FanReading(id: 0, rpm: 2000, minRPM: 0, maxRPM: 0).fraction, 0)
    }
}

final class SensorCatalogTests: XCTestCase {
    func testGroupsByKeyPrefix() {
        XCTAssertEqual(SensorCatalog.describe(key: "Tg0f").group, .gpu)
        XCTAssertEqual(SensorCatalog.describe(key: "Tp01").group, .cpu)
        XCTAssertEqual(SensorCatalog.describe(key: "Te05").group, .cpu)
        XCTAssertEqual(SensorCatalog.describe(key: "TB1T").group, .battery)
        XCTAssertEqual(SensorCatalog.describe(key: "TH0x").group, .ssd)
        XCTAssertEqual(SensorCatalog.describe(key: "Tzzz").group, .other)
    }

    func testUnknownKeyKeepsItsRawName() {
        XCTAssertEqual(SensorCatalog.describe(key: "Tzzz").name, "Tzzz")
    }

    func testHIDSensorUsesItsOwnName() {
        let described = SensorCatalog.describe(key: "hid:PMU tdie1")
        XCTAssertEqual(described.name, "PMU tdie1")
        XCTAssertEqual(described.group, .cpu)
        XCTAssertEqual(SensorCatalog.describe(key: "hid:gas gauge battery").group, .battery)
        XCTAssertEqual(SensorCatalog.describe(key: "hid:NAND CH0 temp").group, .ssd)
    }

    // Review Focus 4: unpopulated sensors read exactly 0.
    func testPlausibleRange() {
        XCTAssertFalse(SensorCatalog.isPlausible(celsius: 0))
        XCTAssertFalse(SensorCatalog.isPlausible(celsius: -3))
        XCTAssertTrue(SensorCatalog.isPlausible(celsius: 0.5))
        XCTAssertTrue(SensorCatalog.isPlausible(celsius: 130))
        XCTAssertFalse(SensorCatalog.isPlausible(celsius: 130.1))
        XCTAssertFalse(SensorCatalog.isPlausible(celsius: .nan))
    }

    // Review Focus 4: the same sensor can arrive twice.
    func testCleanDropsDeadAndRepeatedSensorsAndSortsHottestFirst() {
        func reading(_ key: String, _ celsius: Double) -> TemperatureReading {
            TemperatureReading(key: key, name: key, group: .other, celsius: celsius)
        }
        let cleaned = SensorCatalog.clean([reading("A", 40), reading("B", 0), reading("A", 55), reading("C", 70)])
        XCTAssertEqual(cleaned.map(\.key), ["C", "A"])
        XCTAssertEqual(cleaned.last?.celsius, 40)
    }
}

final class MemoryReadingTests: XCTestCase {
    private func reading(total: UInt64, used: UInt64, wired: UInt64, compressed: UInt64) -> MemoryReading {
        MemoryReading(total: total, used: used, wired: wired, compressed: compressed, cached: 0, free: 0,
                      swapUsed: 0, swapTotal: 0, pressure: .normal)
    }

    func testAppMemoryIsUsedMinusWiredAndCompressed() {
        XCTAssertEqual(reading(total: 100, used: 60, wired: 20, compressed: 10).app, 30)
    }

    func testAppMemoryNeverGoesNegative() {
        XCTAssertEqual(reading(total: 100, used: 10, wired: 20, compressed: 10).app, 0)
    }

    func testUsedFraction() {
        XCTAssertEqual(reading(total: 100, used: 25, wired: 0, compressed: 0).usedFraction, 0.25)
        XCTAssertEqual(reading(total: 0, used: 25, wired: 0, compressed: 0).usedFraction, 0)
    }
}

final class SnapshotTests: XCTestCase {
    func testEmptySnapshotHasNoHottestSensorOrFan() {
        XCTAssertNil(Snapshot.empty.hottest)
        XCTAssertNil(Snapshot.empty.fastestFan)
    }
}
