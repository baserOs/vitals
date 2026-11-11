import XCTest
@testable import VitalsCore

final class TemperatureSummaryTests: XCTestCase {
    private func snapshot(_ temperatures: [TemperatureReading], battery: BatteryReading? = nil) -> Snapshot {
        Snapshot(date: Date(), cpu: nil, memory: nil, gpu: nil, temperatures: temperatures, fans: [],
                 power: nil, battery: battery, processes: [])
    }

    private func reading(_ key: String, _ celsius: Double) -> TemperatureReading {
        let described = SensorCatalog.describe(key: key)
        return TemperatureReading(key: key, name: described.name, group: described.group, celsius: celsius)
    }

    private func battery(celsius: Double?) -> BatteryReading {
        BatteryReading(percent: 80, isCharging: false, isPluggedIn: false, watts: -8, cycleCount: 10,
                       healthPercent: 95, celsius: celsius)
    }

    func testOneReadingPerSpotTheHottestOfEach() {
        let highlights = TemperatureSummary.highlights(for: snapshot([
            reading("Tp01", 61), reading("Tp05", 72), reading("Tg0f", 55), reading("TB1T", 30),
            reading("TB2T", 32), reading("TH0x", 41), reading("Ts0P", 33), reading("Ts1P", 35),
            reading("TaLP", 44),
        ]))
        XCTAssertEqual(highlights.map(\.spot), [.cpu, .gpu, .battery, .ssd, .surface])
        XCTAssertEqual(highlights.map(\.celsius), [72, 55, 32, 41, 35])
        XCTAssertFalse(highlights.contains { $0.isEstimate })
    }

    func testSpotWithoutASensorIsLeftOut() {
        let highlights = TemperatureSummary.highlights(for: snapshot([reading("Tp01", 61)]))
        XCTAssertEqual(highlights.map(\.spot), [.cpu])
    }

    func testBatteryFallsBackToTheBatteryController() {
        let highlights = TemperatureSummary.highlights(for: snapshot([], battery: battery(celsius: 29)))
        XCTAssertEqual(highlights.first { $0.spot == .battery }?.celsius, 29)
    }

    func testSurfaceWithoutASkinSensorIsEstimatedFromTheBattery() {
        let highlights = TemperatureSummary.highlights(for: snapshot([reading("TB1T", 31)]))
        let surface = highlights.first { $0.spot == .surface }
        XCTAssertEqual(surface?.celsius, 31)
        XCTAssertEqual(surface?.isEstimate, true)
    }

    func testNothingToShowForAnEmptySnapshot() {
        XCTAssertTrue(TemperatureSummary.highlights(for: .empty).isEmpty)
    }

    func testSkinSensorsAreGroupedAsSurface() {
        XCTAssertEqual(SensorCatalog.describe(key: "Ts0P").group, .surface)
        XCTAssertEqual(SensorCatalog.describe(key: "Ts0P").name, "Palm rest 1")
    }

    func testASurfaceIsHotLongBeforeAChipIs() {
        XCTAssertEqual(TemperatureSpot.cpu.level(celsius: 60), .normal)
        XCTAssertEqual(TemperatureSpot.cpu.level(celsius: 80), .warm)
        XCTAssertEqual(TemperatureSpot.cpu.level(celsius: 95), .hot)
        XCTAssertEqual(TemperatureSpot.surface.level(celsius: 36), .normal)
        XCTAssertEqual(TemperatureSpot.surface.level(celsius: 40), .warm)
        XCTAssertEqual(TemperatureSpot.surface.level(celsius: 46), .hot)
    }
}

final class LimitTests: XCTestCase {
    func testChipEstimateGrowsWithTheCores() {
        // 4 performance, 4 efficiency, 8 GPU: 16 + 4 + 12.8, rounded up.
        XCTAssertEqual(LimitMath.chipWatts(performanceCores: 4, efficiencyCores: 4, gpuCores: 8), 35)
        // 12 performance, 4 efficiency, 40 GPU: 48 + 4 + 64.
        XCTAssertEqual(LimitMath.chipWatts(performanceCores: 12, efficiencyCores: 4, gpuCores: 40), 120)
    }

    func testChipEstimateWithoutAGPUCoreCount() {
        XCTAssertEqual(LimitMath.chipWatts(performanceCores: 8, efficiencyCores: 2, gpuCores: nil),
                       LimitMath.chipWatts(performanceCores: 8, efficiencyCores: 2, gpuCores: 16))
    }

    func testChipEstimateWithUnknownCores() {
        XCTAssertEqual(LimitMath.chipWatts(performanceCores: 0, efficiencyCores: 0, gpuCores: nil), 30)
    }

    func testSystemLimitIsTheChargerRating() {
        XCTAssertEqual(LimitMath.systemWatts(adapterWatts: 96, chipWatts: 60), 96)
        XCTAssertEqual(MachineLimits(adapterWatts: 140, chipWatts: 60).systemWatts, 140)
        XCTAssertFalse(MachineLimits(adapterWatts: 140, chipWatts: 60).systemIsEstimate)
    }

    func testSystemLimitWithoutAChargerIsEstimated() {
        XCTAssertEqual(LimitMath.systemWatts(adapterWatts: nil, chipWatts: 60), 75)
        XCTAssertEqual(LimitMath.systemWatts(adapterWatts: 0, chipWatts: 58), 75)
        XCTAssertTrue(MachineLimits(adapterWatts: nil, chipWatts: 60).systemIsEstimate)
    }

    func testCeilingStaysAtTheLimitUntilAReadingPassesIt() {
        XCTAssertEqual(LimitMath.ceiling(limit: 96, peak: 40, step: 5), 96)
        XCTAssertEqual(LimitMath.ceiling(limit: 96, peak: 96, step: 5), 96)
        XCTAssertEqual(LimitMath.ceiling(limit: 96, peak: 98, step: 5), 105)
        XCTAssertEqual(LimitMath.ceiling(limit: 96, peak: .nan, step: 5), 96)
    }
}

final class FanLimitTests: XCTestCase {
    func testFanLimitIsTheHighestTopSpeed() {
        let snapshot = Snapshot(date: Date(), cpu: nil, memory: nil, gpu: nil, temperatures: [],
                                fans: [FanReading(id: 0, rpm: 0, minRPM: 1200, maxRPM: 5779),
                                       FanReading(id: 1, rpm: 0, minRPM: 1200, maxRPM: 6241)],
                                power: nil, battery: nil, processes: [])
        XCTAssertEqual(snapshot.fanLimit, 6241)
    }

    func testNoFanLimitWithoutFansOrARange() {
        XCTAssertNil(Snapshot.empty.fanLimit)
        let snapshot = Snapshot(date: Date(), cpu: nil, memory: nil, gpu: nil, temperatures: [],
                                fans: [FanReading(id: 0, rpm: 2000, minRPM: 0, maxRPM: 0)],
                                power: nil, battery: nil, processes: [])
        XCTAssertNil(snapshot.fanLimit)
    }
}

final class BatteryAdapterTests: XCTestCase {
    func testChargerRatingIsRead() {
        let reading = BatterySource.reading(from: [
            "CurrentCapacity": 80, "MaxCapacity": 100, "AdapterDetails": ["Watts": 96],
        ])
        XCTAssertEqual(reading?.adapterWatts, 96)
    }

    func testNoChargerRatingOnBattery() {
        let reading = BatterySource.reading(from: ["CurrentCapacity": 80, "MaxCapacity": 100])
        XCTAssertNotNil(reading)
        XCTAssertNil(reading?.adapterWatts)
    }
}
