import SwiftUI
import VitalisCore

/// The full window: history graphs on top, every reading below. Uses the
/// same rounded cards as the popover, but with a plain soft fill.
struct DashboardView: View {
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
        ScrollView {
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
                        TemperaturesSection(snapshot: snapshot, unit: unit)
                    }
                }
            }
            .padding(16)
        }
        .environment(\.cardStyle, .soft)
        .frame(minWidth: 820, minHeight: 600)
    }

    private func chartSpecs(history: [Snapshot], latest: Snapshot, limits: MachineLimits) -> [ChartSpec] {
        let end = latest.date
        let window = end.addingTimeInterval(-Sampler.historySeconds)...end

        func series(_ value: (Snapshot) -> Double?) -> [ChartPoint] {
            var points: [ChartPoint] = []
            points.reserveCapacity(history.count)
            for snapshot in history {
                if let number = value(snapshot), number.isFinite {
                    points.append(ChartPoint(date: snapshot.date, value: number))
                }
            }
            return points
        }

        /// A range from zero to a little above the highest point.
        func openDomain(_ points: [ChartPoint], atLeast floor: Double) -> ClosedRange<Double> {
            let highest = points.map(\.value).max() ?? 0
            return 0...max(floor, highest * 1.15)
        }

        /// A range from zero to this Mac's limit, the way CPU and memory
        /// run to 100%. Grows only if a reading went past the limit.
        func limitDomain(_ points: [ChartPoint], limit: Double, step: Double) -> ClosedRange<Double> {
            0...LimitMath.ceiling(limit: limit, peak: points.map(\.value).max() ?? 0, step: step)
        }

        func wholeWatts(_ watts: Double) -> String {
            String(format: "%.0f W", watts)
        }

        let cpu = series { $0.cpu.map { $0.total * 100 } }
        let memory = series { $0.memory.map { $0.usedFraction * 100 } }
        let temperature = series { snapshot in
            snapshot.hottest.map { unit == .celsius ? $0.celsius : $0.celsius * 9 / 5 + 32 }
        }
        let system = series { $0.power?.systemWatts }
        let chip = series { snapshot in
            guard let power = snapshot.power, power.cpuWatts != nil || power.gpuWatts != nil else { return nil }
            return (power.cpuWatts ?? 0) + (power.gpuWatts ?? 0)
        }
        let fan = series { $0.fastestFan?.rpm }

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

        let chipNow: Double?
        if let power = latest.power, power.cpuWatts != nil || power.gpuWatts != nil {
            chipNow = (power.cpuWatts ?? 0) + (power.gpuWatts ?? 0)
        } else {
            chipNow = nil
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
        ]
    }
}
