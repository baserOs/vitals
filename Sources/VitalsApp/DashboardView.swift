import SwiftUI
import VitalsCore

/// The full window: history graphs on top, every reading below.
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
        let specs = chartSpecs(history: sampler.history, latest: snapshot)
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
                        MemorySection(snapshot: snapshot)
                        PowerSection(snapshot: snapshot)
                        FansSection(snapshot: snapshot)
                        BatterySection(snapshot: snapshot, unit: unit)
                    }
                    VStack(spacing: 12) {
                        Picker("Sort processes", selection: $sortByMemory) {
                            Text("By CPU").tag(false)
                            Text("By memory").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        ProcessesSection(snapshot: snapshot, limit: 15, sortByMemory: sortByMemory)
                        TemperaturesSection(snapshot: snapshot, unit: unit)
                    }
                }
            }
            .padding(16)
        }
        .frame(minWidth: 820, minHeight: 600)
    }

    private func chartSpecs(history: [Snapshot], latest: Snapshot) -> [ChartSpec] {
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
                      domain: openDomain(system, atLeast: 20), window: window, tint: .orange),
            ChartSpec(title: "CPU + GPU power", value: Format.watts(chipNow), points: chip,
                      domain: openDomain(chip, atLeast: 10), window: window, tint: .green),
            ChartSpec(title: "Fan speed", value: Format.rpm(latest.fastestFan?.rpm), points: fan,
                      domain: openDomain(fan, atLeast: 2000), window: window, tint: .teal),
        ]
    }
}
