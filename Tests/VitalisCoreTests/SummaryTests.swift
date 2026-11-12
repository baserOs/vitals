import XCTest
@testable import VitalisCore

final class TemperatureSummaryTests: XCTestCase {
    private func snapshot(_ temperatures: [TemperatureReading], battery: BatteryReading? = nil) -> Snapshot {
        Snapshot(date: Date(), cpu: nil, memory: nil, gpu: nil, temperatures: temperatures, fans: [],
                 power: nil, battery: battery, apps: [])
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

    func testSurfaceTrustsThePalmRestSensorOverTheWarmerOne() {
        let highlights = TemperatureSummary.highlights(for: snapshot([reading("Ts0P", 50), reading("Ts1P", 34)]))
        let surface = highlights.first { $0.spot == .surface }
        XCTAssertEqual(surface?.celsius, 34)
        XCTAssertEqual(surface?.isEstimate, false)
    }

    func testSurfaceWithoutThePalmRestSensorUsesTheCoolestSkinSensor() {
        let highlights = TemperatureSummary.highlights(for: snapshot([reading("Ts0P", 50), reading("Ts0S", 37)]))
        XCTAssertEqual(highlights.first { $0.spot == .surface }?.celsius, 37)
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
                                power: nil, battery: nil, apps: [])
        XCTAssertEqual(snapshot.fanLimit, 6241)
    }

    func testNoFanLimitWithoutFansOrARange() {
        XCTAssertNil(Snapshot.empty.fanLimit)
        let snapshot = Snapshot(date: Date(), cpu: nil, memory: nil, gpu: nil, temperatures: [],
                                fans: [FanReading(id: 0, rpm: 2000, minRPM: 0, maxRPM: 0)],
                                power: nil, battery: nil, apps: [])
        XCTAssertNil(snapshot.fanLimit)
    }
}

final class BatteryFallbackTests: XCTestCase {
    func testHealthAndTemperatureFromTheUsualKeys() {
        let reading = BatterySource.reading(from: [
            "CurrentCapacity": 80, "MaxCapacity": 100, "AppleRawMaxCapacity": 4500, "DesignCapacity": 5000,
            "Temperature": 3050,
        ])
        XCTAssertEqual(reading?.healthPercent, 90)
        XCTAssertEqual(reading?.celsius, 30.5)
    }

    func testHealthAndTemperatureFromTheFallbackKeys() {
        let reading = BatterySource.reading(from: [
            "CurrentCapacity": 80, "MaxCapacity": 100, "NominalChargeCapacity": 4000,
            "BatteryData": ["DesignCapacity": 5000], "VirtualTemperature": 2900,
        ])
        XCTAssertEqual(reading?.healthPercent, 80)
        XCTAssertEqual(reading?.celsius, 29)
    }

    func testMissingHealthAndTemperatureStayMissing() {
        let reading = BatterySource.reading(from: ["CurrentCapacity": 80, "MaxCapacity": 100])
        XCTAssertNotNil(reading)
        XCTAssertNil(reading?.healthPercent)
        XCTAssertNil(reading?.celsius)
    }

    // A percentage must never be mistaken for a capacity in mAh.
    func testPercentCapacityIsNotUsedForHealth() {
        let reading = BatterySource.reading(from: [
            "CurrentCapacity": 80, "MaxCapacity": 100, "BatteryData": ["MaxCapacity": 100, "DesignCapacity": 5000],
        ])
        XCTAssertNil(reading?.healthPercent)
    }
}

final class ProcessRankingTests: XCTestCase {
    private let processes = [
        ProcessReading(pid: 1, name: "a", cpu: 0.10, memoryBytes: 300),
        ProcessReading(pid: 2, name: "b", cpu: 0.90, memoryBytes: 100),
        ProcessReading(pid: 3, name: "c", cpu: 0.00, memoryBytes: 900),
        ProcessReading(pid: 4, name: "d", cpu: 0.00, memoryBytes: 900),
        ProcessReading(pid: 5, name: "e", cpu: 0.50, memoryBytes: 500),
    ]

    func testByMemoryIsHighestFirst() {
        let ranked = processes.ranked(by: .memory, limit: 10)
        XCTAssertEqual(ranked.map(\.pid), [3, 4, 5, 1, 2])
        XCTAssertEqual(ranked.map(\.memoryBytes), ranked.map(\.memoryBytes).sorted(by: >))
    }

    func testByCPUIsHighestFirst() {
        XCTAssertEqual(processes.ranked(by: .cpu, limit: 10).map(\.pid), [2, 5, 1, 3, 4])
    }

    func testLimit() {
        XCTAssertEqual(processes.ranked(by: .memory, limit: 2).map(\.pid), [3, 4])
        XCTAssertTrue(processes.ranked(by: .memory, limit: 0).isEmpty)
    }

    func testProcessMemoryNeverShowsABiggerAmountAsASmallerNumber() {
        XCTAssertEqual(Format.processMemory(835 * 1_048_576), "835 MB")
        XCTAssertEqual(Format.processMemory(1010 * 1_048_576), "0.99 GB")
        XCTAssertEqual(Format.processMemory(2 * 1_073_741_824), "2.00 GB")
        XCTAssertEqual(Format.processMemory(1000), "<1 MB")
    }
}

final class ProcessGroupTests: XCTestCase {
    private let safari = AppIdentity(key: "app:/Applications/Safari.app", name: "Safari")
    private let finder = AppIdentity(key: "app:/System/Library/CoreServices/Finder.app", name: "Finder")

    func testAnAppAddsUpItsProcesses() {
        let groups = ProcessSource.groups(from: [
            safari: [
                ProcessReading(pid: 10, name: "Safari", cpu: 0.10, memoryBytes: 300),
                ProcessReading(pid: 11, name: "com.apple.WebKit.WebContent", cpu: 0.40, memoryBytes: 900),
                ProcessReading(pid: 12, name: "com.apple.WebKit.WebContent", cpu: 0.00, memoryBytes: 700),
            ],
            finder: [ProcessReading(pid: 20, name: "Finder", cpu: 0.05, memoryBytes: 200)],
        ])
        let byMemory = groups.ranked(by: .memory, limit: 10)
        XCTAssertEqual(byMemory.map(\.name), ["Safari", "Finder"])
        XCTAssertEqual(byMemory.first?.memoryBytes, 1900)
        XCTAssertEqual(byMemory.first?.cpu ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(byMemory.first?.processCount, 3)
        XCTAssertEqual(byMemory.first?.members.ranked(by: .memory, limit: 10).map(\.pid), [11, 12, 10])
    }

    func testAnAppKeepsOnlyItsBusiestProcessesButCountsThemAll() {
        let many = (0..<40).map { ProcessReading(pid: Int32(100 + $0), name: "helper", cpu: 0, memoryBytes: UInt64($0)) }
        let group = ProcessSource.groups(from: [safari: many]).first
        XCTAssertEqual(group?.processCount, 40)
        XCTAssertLessThanOrEqual(group?.members.count ?? 99, ProcessSource.memberLimit * 2)
        // The heaviest one is always among those kept.
        XCTAssertTrue(group?.members.contains { $0.pid == 139 } ?? false)
    }

    func testBusiestKeepsTheTopOfBothOrdersWithoutRepeats() {
        let processes = [
            ProcessReading(pid: 1, name: "a", cpu: 0.9, memoryBytes: 10),
            ProcessReading(pid: 2, name: "b", cpu: 0.0, memoryBytes: 900),
            ProcessReading(pid: 3, name: "c", cpu: 0.1, memoryBytes: 20),
        ]
        XCTAssertEqual(Set(processes.busiest(limit: 1).map(\.pid)), [1, 2])
        XCTAssertEqual(processes.busiest(limit: 3).count, 3)
    }
}

final class AppNamingTests: XCTestCase {
    func testTheOutermostAppBundleWins() {
        let path = "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework"
            + "/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)"
        XCTAssertEqual(AppNaming.app(inPath: path)?.name, "Google Chrome")
        XCTAssertEqual(AppNaming.app(inPath: path)?.key, "app:/Applications/Google Chrome.app")
    }

    func testAPathOutsideAnyAppHasNoApp() {
        XCTAssertNil(AppNaming.app(inPath: "/usr/libexec/trustd"))
        XCTAssertNil(AppNaming.app(inPath: ""))
    }

    // A browser tab runs from a system folder; only its owner says whose it is.
    func testAProcessIsCountedUnderTheAppItWorksFor() {
        let identity = AppNaming.identity(
            processName: "com.apple.WebKit.WebContent",
            path: "/System/Library/Frameworks/WebKit.framework/XPCServices/com.apple.WebKit.WebContent.xpc"
                + "/Contents/MacOS/com.apple.WebKit.WebContent",
            ownerName: "Safari", ownerPath: "/Applications/Safari.app/Contents/MacOS/Safari")
        XCTAssertEqual(identity.name, "Safari")
    }

    func testAProcessWithNoOwnerUsesItsOwnApp() {
        let identity = AppNaming.identity(processName: "Finder",
                                          path: "/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder",
                                          ownerName: nil, ownerPath: nil)
        XCTAssertEqual(identity.name, "Finder")
    }

    func testAToolStartedFromATerminalIsCountedUnderTheTerminal() {
        let identity = AppNaming.identity(processName: "node", path: "/opt/homebrew/bin/node", ownerName: "Terminal",
                                          ownerPath: "/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal")
        XCTAssertEqual(identity.name, "Terminal")
    }

    func testSameNamedHelpersOutsideAnyAppAreGathered() {
        let first = AppNaming.identity(processName: "mdworker_shared", path: "/usr/libexec/mdworker_shared",
                                       ownerName: nil, ownerPath: nil)
        let second = AppNaming.identity(processName: "mdworker_shared", path: nil, ownerName: nil, ownerPath: nil)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.name, "mdworker_shared")
    }
}

final class GPUShareTests: XCTestCase {
    func testParsesTheOwnerOfAConnection() {
        let owner = GPUShareMath.parseCreator("pid 517, WindowServer")
        XCTAssertEqual(owner?.pid, 517)
        XCTAssertEqual(owner?.name, "WindowServer")
        XCTAssertEqual(GPUShareMath.parseCreator("pid 88, Google Chrome He")?.name, "Google Chrome He")
        XCTAssertNil(GPUShareMath.parseCreator("WindowServer"))
        XCTAssertNil(GPUShareMath.parseCreator("pid x, y"))
    }

    func testSharesSplitTheUtilizationInProportion() {
        let shares = GPUShareMath.shares(previous: [1: 100, 2: 100, 3: 100], current: [1: 400, 2: 200, 3: 100],
                                         utilization: 0.4)
        XCTAssertEqual(shares[1] ?? 0, 0.3, accuracy: 0.0001)
        XCTAssertEqual(shares[2] ?? 0, 0.1, accuracy: 0.0001)
        XCTAssertNil(shares[3])
        XCTAssertEqual(shares.values.reduce(0, +), 0.4, accuracy: 0.0001)
    }

    func testANewProcessOrABackwardsCounterGetsNothing() {
        let shares = GPUShareMath.shares(previous: [1: 500], current: [1: 400, 2: 900], utilization: 0.5)
        XCTAssertTrue(shares.isEmpty)
    }

    func testNoSharesWhenTheGPUIsIdle() {
        XCTAssertTrue(GPUShareMath.shares(previous: [1: 1], current: [1: 9], utilization: 0).isEmpty)
    }

    func testTopIsBiggestFirstAndLimited() {
        let top = GPUShareMath.top([
            AppIdentity(key: "a", name: "A"): 0.1,
            AppIdentity(key: "b", name: "B"): 0.3,
            AppIdentity(key: "c", name: "C"): 0.2,
        ], limit: 2)
        XCTAssertEqual(top.map(\.name), ["B", "C"])
    }
}

final class NetworkTests: XCTestCase {
    func testRatesAreBytesPerSecondAcrossInterfaces() {
        let reading = NetworkMath.rates(
            previous: ["en0": InterfaceCounters(received: 1000, sent: 500), "en1": InterfaceCounters(received: 0, sent: 0)],
            current: ["en0": InterfaceCounters(received: 5000, sent: 1500), "en1": InterfaceCounters(received: 2000, sent: 0)],
            seconds: 2)
        XCTAssertEqual(reading?.downloadBytesPerSecond, 3000)
        XCTAssertEqual(reading?.uploadBytesPerSecond, 500)
    }

    // The counters are 32 bits wide and wrap to zero every 4 GB.
    func testACounterThatWrappedStillGivesTheRightAmount() {
        let reading = NetworkMath.rates(
            previous: ["en0": InterfaceCounters(received: UInt32.max - 99, sent: 0)],
            current: ["en0": InterfaceCounters(received: 900, sent: 0)],
            seconds: 1)
        XCTAssertEqual(reading?.downloadBytesPerSecond, 1000)
    }

    func testAnInterfaceThatJustAppearedIsNotCounted() {
        let reading = NetworkMath.rates(previous: [:], current: ["en0": InterfaceCounters(received: 9_000_000, sent: 9)],
                                        seconds: 1)
        XCTAssertEqual(reading?.downloadBytesPerSecond, 0)
    }

    func testNoRateWithoutElapsedTime() {
        XCTAssertNil(NetworkMath.rates(previous: [:], current: [:], seconds: 0))
    }

    func testBitRateFormatting() {
        XCTAssertEqual(Format.bitRate(bytesPerSecond: 0), "0 kb/s")
        XCTAssertEqual(Format.bitRate(bytesPerSecond: 42_500), "340 kb/s")
        XCTAssertEqual(Format.bitRate(bytesPerSecond: 1_550_000), "12.4 Mb/s")
        XCTAssertEqual(Format.bitRate(bytesPerSecond: 31_250_000), "250 Mb/s")
        XCTAssertEqual(Format.bitRate(bytesPerSecond: 150_000_000), "1.20 Gb/s")
        XCTAssertEqual(Format.bitRate(bytesPerSecond: nil), Format.missing)
    }

    func testRoundCeilingMovesInClearSteps() {
        XCTAssertEqual(LimitMath.roundCeiling(0.2, floor: 1), 1)
        XCTAssertEqual(LimitMath.roundCeiling(3.2, floor: 1), 5)
        XCTAssertEqual(LimitMath.roundCeiling(12, floor: 1), 20)
        XCTAssertEqual(LimitMath.roundCeiling(100, floor: 1), 100)
        XCTAssertEqual(LimitMath.roundCeiling(640, floor: 1), 1000)
        XCTAssertEqual(LimitMath.roundCeiling(.nan, floor: 1), 1)
    }
}

final class HistoryPointTests: XCTestCase {
    func testKeepsOnlyWhatTheGraphsNeed() {
        let snapshot = Snapshot(
            date: Date(timeIntervalSince1970: 100),
            cpu: CPUReading(total: 0.25, cores: [], loadAverage: []),
            memory: nil, gpu: nil,
            temperatures: [TemperatureReading(key: "Tp01", name: "Tp01", group: .cpu, celsius: 61)],
            fans: [FanReading(id: 0, rpm: 2100, minRPM: 1200, maxRPM: 6000)],
            power: PowerReading(systemWatts: 20, adapterWatts: nil, cpuWatts: 6, gpuWatts: 2),
            battery: nil, apps: [],
            network: NetworkReading(downloadBytesPerSecond: 1000, uploadBytesPerSecond: 10))
        let point = HistoryPoint(snapshot)
        XCTAssertEqual(point.date, snapshot.date)
        XCTAssertEqual(point.cpu, 0.25)
        XCTAssertNil(point.memory)
        XCTAssertEqual(point.hottestCelsius, 61)
        XCTAssertEqual(point.systemWatts, 20)
        XCTAssertEqual(point.chipWatts, 8)
        XCTAssertEqual(point.fanRPM, 2100)
        XCTAssertEqual(point.downloadBytesPerSecond, 1000)
        XCTAssertEqual(point.uploadBytesPerSecond, 10)
    }

    func testNoChipPowerWithoutEitherReading() {
        let snapshot = Snapshot(date: Date(), cpu: nil, memory: nil, gpu: nil, temperatures: [], fans: [],
                                power: PowerReading(systemWatts: 20, adapterWatts: nil, cpuWatts: nil, gpuWatts: nil),
                                battery: nil, apps: [])
        XCTAssertNil(HistoryPoint(snapshot).chipWatts)
    }

    func testTheSamplerShowsLoadedHistoryOldestFirst() {
        let sampler = Sampler()
        let points = (0..<5).map { HistoryPoint(date: Date(timeIntervalSince1970: Double($0)), cpu: Double($0) / 10) }
        sampler.load(latest: .empty, history: points, limits: MachineLimits(adapterWatts: 96, chipWatts: 60))
        XCTAssertEqual(sampler.history, points)
        XCTAssertEqual(sampler.limits.systemWatts, 96)
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
