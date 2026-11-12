import AppKit
import SwiftUI
import XCTest
@testable import Vitalis
@testable import VitalisCore

/// Draws the dashboard and the popover with fixed sample data and saves
/// them as PNG files, so a build on a machine with no sensors still shows
/// what the screens look like.
///
/// Runs only when VITALIS_SCREENSHOTS names a folder:
///
///     VITALIS_SCREENSHOTS=/tmp/screens swift test --filter ScreenshotTests
///
/// Liquid Glass needs a live window behind it and is not drawn here; the
/// popover's cards show their content on a plain backdrop.
@MainActor
final class ScreenshotTests: XCTestCase {
    func testRenderScreens() throws {
        guard let path = ProcessInfo.processInfo.environment["VITALIS_SCREENSHOTS"], !path.isEmpty else {
            throw XCTSkip("Set VITALIS_SCREENSHOTS to a folder to render the screens.")
        }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let sampler = Sampler()
        sampler.load(latest: SampleData.snapshot, history: SampleData.history,
                     limits: MachineLimits(adapterWatts: 96, chipWatts: 60))

        for (scheme, name) in [(ColorScheme.light, "light"), (ColorScheme.dark, "dark")] {
            let window = scheme == .dark ? Color(white: 0.13) : Color(white: 0.93)
            let dashboard = DashboardContent()
                .frame(width: 920)
                .background(window)
                .environmentObject(sampler)
                .environment(\.colorScheme, scheme)
            try save(dashboard, as: "dashboard-\(name)", in: folder)

            let popover = PopoverSections()
                .padding(.bottom, 8)
                .frame(width: 340)
                .background(window)
                .environmentObject(sampler)
                .environment(\.colorScheme, scheme)
            try save(popover, as: "popover-\(name)", in: folder)

            // What a click unfolds: an app's processes and the full sensor
            // list. Above them, the list in its other order.
            let unfolded = VStack(alignment: .leading, spacing: 12) {
                ProcessesSection(snapshot: SampleData.snapshot, limit: 20, sortByMemory: true)
                    .environment(\.cardStyle, .soft)
                ForEach(SampleData.snapshot.apps.ranked(by: .memory, limit: 2)) { group in
                    ProcessGroupRow(group: group, order: .memory, isOpen: true) {}
                }
                ForEach(SensorGroup.allCases, id: \.self) { group in
                    TemperatureGroup(group: group,
                                     readings: SampleData.snapshot.temperatures.filter { $0.group == group },
                                     unit: .celsius)
                }
            }
            .padding(16)
            .frame(width: 440)
            .background(window)
            .environment(\.colorScheme, scheme)
            try save(unfolded, as: "unfolded-\(name)", in: folder)
        }
    }

    private func save<Content: View>(_ view: Content, as name: String, in folder: URL) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Could not draw \(name)")
            return
        }
        XCTAssertGreaterThan(image.size.width, 100, name)
        XCTAssertGreaterThan(image.size.height, 100, name)
        try png.write(to: folder.appendingPathComponent(name + ".png"))
    }
}

/// A believable Mac under moderate load.
enum SampleData {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    static let snapshot: Snapshot = {
        let cores = (0..<10).map { index in
            CoreReading(id: index, usage: [0.42, 0.35, 0.18, 0.12, 0.91, 0.74, 0.55, 0.31, 0.22, 0.08][index],
                        kind: index < 4 ? .efficiency : .performance)
        }
        let gigabyte: UInt64 = 1_073_741_824
        func megabytes(_ amount: Double) -> UInt64 { UInt64(amount * 1_048_576) }

        var temperatures: [TemperatureReading] = []
        func sensor(_ key: String, _ celsius: Double) {
            let described = SensorCatalog.describe(key: key)
            temperatures.append(TemperatureReading(key: key, name: described.name, group: described.group,
                                                   celsius: celsius))
        }
        for (index, celsius) in [71.0, 68, 66, 64, 63, 61, 60, 58, 57, 55].enumerated() {
            sensor(String(format: "Tp%02d", index), celsius)
        }
        for (index, celsius) in [59.0, 57, 54, 52].enumerated() { sensor("Tg0\(index)", celsius) }
        sensor("TB1T", 31)
        sensor("TB2T", 32)
        sensor("TH0x", 43)
        sensor("Ts0P", 49)
        sensor("Ts1P", 34)
        sensor("TaLP", 41)
        sensor("TaRF", 44)
        sensor("TW0P", 46)
        for (name, celsius) in [("PMU tdie1", 62.0), ("PMU tdie2", 60), ("PMU tdev1", 48), ("PMU tcal", 45),
                                ("gas gauge battery", 31.5), ("NAND CH0 temp", 44)] {
            sensor("hid:" + name, celsius)
        }

        func app(_ name: String, _ members: [(String, Double, Double)]) -> ProcessGroup {
            let processes = members.enumerated().map { index, member in
                ProcessReading(pid: Int32(abs(name.hashValue % 30_000)) + Int32(index), name: member.0,
                               cpu: member.1, memoryBytes: megabytes(member.2))
            }
            return ProcessGroup(id: "app:/Applications/\(name).app", name: name,
                                cpu: processes.reduce(0) { $0 + $1.cpu },
                                memoryBytes: processes.reduce(0) { $0 + $1.memoryBytes },
                                members: processes, processCount: processes.count)
        }
        let apps = [
            app("Safari", [("Safari", 0.04, 351), ("com.apple.WebKit.WebContent", 0.21, 1024),
                           ("com.apple.WebKit.WebContent", 0.02, 835), ("com.apple.WebKit.WebContent", 0.0, 720),
                           ("com.apple.WebKit.GPU", 0.06, 172), ("com.apple.WebKit.Networking", 0.01, 64)]),
            app("Visual Studio Code", [("Code Helper (Renderer)", 0.29, 279), ("Code Helper", 0.24, 193),
                                       ("Code", 0.03, 140), ("Code Helper (GPU)", 0.02, 88)]),
            app("Claude", [("Claude Helper (Renderer)", 0.03, 751), ("Claude", 0.01, 258), ("Claude Helper", 0.0, 149)]),
            app("Spotify", [("Spotify", 0.02, 279), ("Spotify Helper (Renderer)", 0.03, 262), ("Spotify Helper", 0.0, 162)]),
            app("Xcode", [("Xcode", 0.52, 1410), ("SourceKitService", 0.33, 620), ("swift-frontend", 0.9, 410)]),
            app("Terminal", [("Terminal", 0.01, 96), ("zsh", 0.0, 8), ("node", 0.12, 310)]),
            app("Finder", [("Finder", 0.0, 121)]),
            app("Mail", [("Mail", 0.0, 210), ("com.apple.WebKit.WebContent", 0.0, 96)]),
            app("Vitalis", [("Vitalis", 0.004, 58)]),
            app("Notes", [("Notes", 0.0, 143)]),
            app("Music", [("Music", 0.01, 188)]),
            app("Preview", [("Preview", 0.0, 77)]),
        ]

        return Snapshot(
            date: now,
            cpu: CPUReading(total: 0.39, cores: cores, loadAverage: [3.21, 2.84, 2.40]),
            memory: MemoryReading(total: 16 * gigabyte, used: UInt64(11.4 * Double(gigabyte)),
                                  wired: UInt64(2.3 * Double(gigabyte)), compressed: UInt64(1.6 * Double(gigabyte)),
                                  cached: UInt64(3.1 * Double(gigabyte)), free: UInt64(1.5 * Double(gigabyte)),
                                  swapUsed: megabytes(512), swapTotal: 2 * gigabyte, pressure: .normal),
            gpu: GPUReading(usage: 0.27),
            temperatures: SensorCatalog.clean(temperatures),
            fans: [FanReading(id: 0, rpm: 2140, minRPM: 1200, maxRPM: 5779),
                   FanReading(id: 1, rpm: 2310, minRPM: 1200, maxRPM: 6241)],
            power: PowerReading(systemWatts: 23.4, adapterWatts: 41.2, cpuWatts: 9.8, gpuWatts: 3.1),
            battery: BatteryReading(percent: 82, isCharging: true, isPluggedIn: true, watts: 17.8, cycleCount: 143,
                                    healthPercent: 92, celsius: 31.4, adapterWatts: 96),
            apps: apps,
            gpuApps: [
                GPUProcessReading(id: "a", name: "WindowServer", usage: 0.11),
                GPUProcessReading(id: "b", name: "Safari", usage: 0.09),
                GPUProcessReading(id: "c", name: "Visual Studio Code", usage: 0.04),
                GPUProcessReading(id: "d", name: "Claude", usage: 0.025),
                GPUProcessReading(id: "e", name: "Spotify", usage: 0.004),
            ],
            network: NetworkReading(downloadBytesPerSecond: 1_550_000, uploadBytesPerSecond: 42_500)
        )
    }()

    /// Ten minutes of gentle waves ending at the snapshot's values.
    static let history: [HistoryPoint] = (0..<300).map { index in
        let t = Double(index)
        let wave = sin(t / 17) * 0.5 + 0.5
        let burst = index > 180 && index < 230 ? 1.0 : 0.0
        return HistoryPoint(
            date: now.addingTimeInterval(Double(index - 299) * 2),
            cpu: 0.18 + 0.25 * wave + 0.3 * burst,
            memory: 0.66 + 0.05 * sin(t / 60),
            hottestCelsius: 52 + 14 * wave + 12 * burst,
            systemWatts: 14 + 12 * wave + 30 * burst,
            chipWatts: 5 + 8 * wave + 24 * burst,
            fanRPM: burst > 0 ? 3400 + 300 * wave : 2000 + 200 * wave,
            downloadBytesPerSecond: 200_000 + 1_400_000 * wave + 9_000_000 * burst,
            uploadBytesPerSecond: 20_000 + 30_000 * wave
        )
    }
}
