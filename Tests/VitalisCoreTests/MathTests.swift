import XCTest
@testable import VitalisCore

final class CPUMathTests: XCTestCase {
    func testUsageIsBusyShareOfElapsedTicks() {
        let previous = CPUTicks(user: 100, system: 50, idle: 850, nice: 0)
        let current = CPUTicks(user: 200, system: 100, idle: 1700, nice: 0)
        XCTAssertEqual(CPUMath.usage(previous: previous, current: current), 0.15, accuracy: 1e-9)
    }

    func testNoElapsedTicksIsZero() {
        let ticks = CPUTicks(user: 10, system: 10, idle: 10, nice: 10)
        XCTAssertEqual(CPUMath.usage(previous: ticks, current: ticks), 0)
    }

    func testCounterGoingBackwardsIsZero() {
        let earlier = CPUTicks(user: 100, system: 50, idle: 850, nice: 0)
        let later = CPUTicks(user: 200, system: 100, idle: 1700, nice: 0)
        XCTAssertEqual(CPUMath.usage(previous: later, current: earlier), 0)
    }

    func testFullyBusyIsOne() {
        let previous = CPUTicks(user: 0, system: 0, idle: 500, nice: 0)
        let current = CPUTicks(user: 60, system: 30, idle: 500, nice: 10)
        XCTAssertEqual(CPUMath.usage(previous: previous, current: current), 1)
    }
}

final class EnergyMathTests: XCTestCase {
    func testUnits() {
        XCTAssertEqual(EnergyMath.watts(deltaEnergy: 2_000, unit: "mJ", seconds: 2), 1.0)
        XCTAssertEqual(EnergyMath.watts(deltaEnergy: 2_000_000, unit: "uJ", seconds: 2), 1.0)
        XCTAssertEqual(EnergyMath.watts(deltaEnergy: 2_000_000_000, unit: "nJ", seconds: 2), 1.0)
    }

    func testUnitWithSurroundingSpaces() {
        XCTAssertEqual(EnergyMath.watts(deltaEnergy: 2_000, unit: " mJ ", seconds: 2), 1.0)
    }

    func testInvalidInputIsNil() {
        XCTAssertNil(EnergyMath.watts(deltaEnergy: 5, unit: "mJ", seconds: 0))
        XCTAssertNil(EnergyMath.watts(deltaEnergy: 5, unit: "kWh", seconds: 2))
        XCTAssertNil(EnergyMath.watts(deltaEnergy: -5, unit: "mJ", seconds: 2))
    }
}

final class SampleGapTests: XCTestCase {
    // Review Focus 1: a long pause must not turn into a spike.
    func testGapUpToThreeIntervalsIsUsable() {
        XCTAssertTrue(SampleGap.isUsable(elapsed: 2.1, interval: 2))
        XCTAssertTrue(SampleGap.isUsable(elapsed: 6.0, interval: 2))
    }

    func testLongerGapIsDiscarded() {
        XCTAssertFalse(SampleGap.isUsable(elapsed: 6.1, interval: 2))
        XCTAssertFalse(SampleGap.isUsable(elapsed: 3600, interval: 2))
    }

    func testZeroElapsedIsDiscarded() {
        XCTAssertFalse(SampleGap.isUsable(elapsed: 0, interval: 2))
    }
}

final class RingBufferTests: XCTestCase {
    func testKeepsOnlyTheMostRecent() {
        var buffer = RingBuffer<Int>(capacity: 3)
        for value in 1...5 { buffer.append(value) }
        XCTAssertEqual(buffer.elements, [3, 4, 5])
        XCTAssertEqual(buffer.count, 3)
    }

    func testBelowCapacityKeepsOrder() {
        var buffer = RingBuffer<Int>(capacity: 5)
        buffer.append(1)
        buffer.append(2)
        XCTAssertEqual(buffer.elements, [1, 2])
    }

    func testCapacityIsAtLeastOne() {
        var buffer = RingBuffer<Int>(capacity: 0)
        buffer.append(1)
        buffer.append(2)
        XCTAssertEqual(buffer.elements, [2])
    }
}

final class SamplerTests: XCTestCase {
    func testHistoryCoversTenMinutes() {
        XCTAssertEqual(Sampler.historyCapacity(interval: 1), 600)
        XCTAssertEqual(Sampler.historyCapacity(interval: 2), 300)
        XCTAssertEqual(Sampler.historyCapacity(interval: 5), 120)
    }

    func testInvalidIntervalStillGivesACapacity() {
        XCTAssertEqual(Sampler.historyCapacity(interval: 0), 600)
    }
}
