import SwiftUI
import VitalisCore

/// The full window: history graphs on top, every reading below. Uses the
/// same rounded cards as the popover, but with a plain soft fill.
struct DashboardView: View {
    var body: some View {
        ScrollView {
            DashboardContent()
        }
        .frame(minWidth: 820, minHeight: 600)
    }
}

/// Everything in the dashboard, without the scrolling around it.
struct DashboardContent: View {
    @EnvironmentObject private var sampler: Sampler
    @AppStorage(SettingsKey.temperatureUnit) private var unit: TemperatureUnit = .celsius
    @State private var sortByMemory = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        let snapshot = sampler.latest
        let limits = sampler.limits
        let specs = chartSpecs(history: sampler.history, latest: snapshot, limits: limits)
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(specs) { spec in
                    HistoryChart(spec: spec)
                }
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 12) {
                    CPUSection(snapshot: snapshot)
                    GPUSection(snapshot: snapshot)
                    MemorySection(snapshot: snapshot, detailed: true)
                    PowerSection(snapshot: snapshot, limits: limits)
                    FansSection(snapshot: snapshot)
                    BatterySection(snapshot: snapshot, unit: unit)
                }
                VStack(spacing: 12) {
                    Picker("Sort processes", selection: $sortByMemory) {
                        Text("By Processor").tag(false)
                        Text("By memory").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    ProcessesSection(snapshot: snapshot, limit: 20, sortByMemory: sortByMemory)
                    GPUAppsSection(snapshot: snapshot)
                    TemperaturesSection(snapshot: snapshot, unit: unit, listsEverySensor: true)
                }
            }
        }
        .padding(16)
        .environment(\.cardStyle, .soft)
    }

    private func chartSpecs(history: [HistoryPoint], latest: Snapshot, limits: MachineLimits) -> [ChartSpec] {
        let end = latest.date
        let window = end.addingTimeInterval(-Sampler.historySeconds)...end

        func series(_ value: (HistoryPoint) -> Double?) -> [ChartPoint] {
            var points: [ChartPoint] = []
            points.reserveCapacity(history.count)
            for point in history {
                if let number = value(point), number.isFinite {
                    points.append(ChartPoint(date: point.date, value: number))
                }
            }
            return points
        }

        func highest(_ points: [ChartPoint]) -> Double {
            points.map(\.value).max() ?? 0
        }

        /// A range from zero to a little above the highest point.
        func openDomain(_ points: [ChartPoint], atLeast floor: Double) -> ClosedRange<Double> {
            0...max(floor, highest(points) * 1.15)
        }

        /// A range from zero to this Mac's limit, the way CPU and memory
        /// run to 100%. Grows only if a reading went past the limit.
        func limitDomain(_ points: [ChartPoint], limit: Double, step: Double) -> ClosedRange<Double> {
            0...LimitMath.ceiling(limit: limit, peak: highest(points), step: step)
        }

        /// A range from zero to the next round number above the highest
        /// point, for a value with no limit of its own.
        func roundDomain(_ points: [ChartPoint], atLeast floor: Double) -> ClosedRange<Double> {
            0...LimitMath.roundCeiling(highest(points), floor: floor)
        }

        func wholeWatts(_ watts: Double) -> String {
            String(format: "%.0f W", watts)
        }

        let megabit = 125_000.0  // bytes per second in one megabit per second

        let cpu = series { $0.cpu.map { $0 * 100 } }
        let memory = series { $0.memory.map { $0 * 100 } }
        let temperature = series { point in
            point.hottestCelsius.map { unit == .celsius ? $0 : $0 * 9 / 5 + 32 }
        }
        let system = series { $0.systemWatts }
        let chip = series { $0.chipWatts }
        let fan = series { $0.fanRPM }
        let download = series { $0.downloadBytesPerSecond.map { $0 / megabit } }
        let upload = series { $0.uploadBytesPerSecond.map { $0 / megabit } }

        // System power runs to the charger rating, or to an estimate until
        // a charger has been seen.
        let systemTop = wholeWatts(limits.systemWatts)
        let systemLimit: String = limits.systemIsEstimate ? "of ≈\(systemTop)" : "of \(systemTop) charger"
        let systemDomain = limitDomain(system, limit: limits.systemWatts, step: 5)

        // Estimated from the core counts: macOS does not publish it.
        let chipLimit: String = "of ≈\(wholeWatts(limits.chipWatts))"
        let chipDomain = limitDomain(chip, limit: limits.chipWatts, step: 5)

        // The top speed the fan itself reports.
        let fanDomain: ClosedRange<Double>
        let fanLimitText: String?
        if let fanLimit = latest.fanLimit {
            fanDomain = limitDomain(fan, limit: fanLimit, step: 500)
            fanLimitText = "of \(Int(fanLimit.rounded()))"
        } else {
            fanDomain = openDomain(fan, atLeast: 2000)
            fanLimitText = nil
        }

        var chipNow: Double?
        if let power = latest.power, power.cpuWatts != nil || power.gpuWatts != nil {
            chipNow = (power.cpuWatts ?? 0) + (power.gpuWatts ?? 0)
        }

        return [
            ChartSpec(title: "CPU", value: Format.percent(latest.cpu?.total), points: cpu,
                      domain: 0...100, window: window, tint: .blue),
            ChartSpec(title: "Memory", value: Format.percent(latest.memory?.usedFraction), points: memory,
                      domain: 0...100, window: window, tint: .purple),
            ChartSpec(title: "Hottest sensor", value: Format.temperature(latest.hottest?.celsius, unit: unit),
                      points: temperature, domain: openDomain(temperature, atLeast: unit == .celsius ? 100 : 212),
                      window: window, tint: .red),
            ChartSpec(title: "System power", value: Format.watts(latest.power?.systemWatts), points: system,
                      limit: systemLimit, domain: systemDomain, window: window, tint: .orange),
            ChartSpec(title: "CPU + GPU power", value: Format.watts(chipNow), points: chip,
                      limit: chipLimit, domain: chipDomain, window: window, tint: .green),
            ChartSpec(title: "Fan speed", value: Format.rpm(latest.fastestFan?.rpm), points: fan,
                      limit: fanLimitText, domain: fanDomain, window: window, tint: .teal),
            // The network has no limit of its own, so these scale to what
            // was seen, in megabits per second.
            ChartSpec(title: "Download",
                      value: Format.bitRate(bytesPerSecond: latest.network?.downloadBytesPerSecond),
                      points: download, limit: "axis in Mb/s", domain: roundDomain(download, atLeast: 1),
                      window: window, tint: .cyan),
            ChartSpec(title: "Upload",
                      value: Format.bitRate(bytesPerSecond: latest.network?.uploadBytesPerSecond),
                      points: upload, limit: "axis in Mb/s", domain: roundDomain(upload, atLeast: 1),
                      window: window, tint: .mint),
        ]
    }
}
