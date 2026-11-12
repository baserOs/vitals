import Foundation

public enum CoreKind: String, Sendable {
    case performance
    case efficiency
}

public struct CoreReading: Sendable, Equatable, Identifiable {
    public let id: Int
    /// 0...1
    public let usage: Double
    public let kind: CoreKind

    public init(id: Int, usage: Double, kind: CoreKind) {
        self.id = id
        self.usage = usage
        self.kind = kind
    }
}

public struct CPUReading: Sendable, Equatable {
    /// 0...1 across all cores.
    public let total: Double
    public let cores: [CoreReading]
    /// 1, 5 and 15 minute load averages.
    public let loadAverage: [Double]

    public init(total: Double, cores: [CoreReading], loadAverage: [Double]) {
        self.total = total
        self.cores = cores
        self.loadAverage = loadAverage
    }
}

public enum MemoryPressure: String, Sendable {
    case normal
    case warning
    case critical
}

public struct MemoryReading: Sendable, Equatable {
    public let total: UInt64
    /// App memory + wired + compressed, as Activity Monitor counts it.
    public let used: UInt64
    public let wired: UInt64
    public let compressed: UInt64
    public let cached: UInt64
    public let free: UInt64
    public let swapUsed: UInt64
    public let swapTotal: UInt64
    public let pressure: MemoryPressure

    public init(total: UInt64, used: UInt64, wired: UInt64, compressed: UInt64, cached: UInt64,
                free: UInt64, swapUsed: UInt64, swapTotal: UInt64, pressure: MemoryPressure) {
        self.total = total
        self.used = used
        self.wired = wired
        self.compressed = compressed
        self.cached = cached
        self.free = free
        self.swapUsed = swapUsed
        self.swapTotal = swapTotal
        self.pressure = pressure
    }

    /// Memory held by apps: used minus wired and compressed.
    public var app: UInt64 {
        let other = wired &+ compressed
        return used > other ? used - other : 0
    }

    /// 0...1
    public var usedFraction: Double {
        total > 0 ? min(1, Double(used) / Double(total)) : 0
    }
}

public struct GPUReading: Sendable, Equatable {
    /// 0...1
    public let usage: Double

    public init(usage: Double) {
        self.usage = usage
    }
}

public enum SensorGroup: String, Sendable, CaseIterable {
    case cpu
    case gpu
    case battery
    case ssd
    /// The outside of the case, where hands rest.
    case surface
    case other

    public var title: String {
        switch self {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .battery: return "Battery"
        case .ssd: return "SSD"
        case .surface: return "Surface"
        case .other: return "Other"
        }
    }
}

public struct TemperatureReading: Sendable, Equatable, Identifiable {
    /// SMC key, or "hid:" plus the sensor name for HID sensors.
    public let key: String
    public let name: String
    public let group: SensorGroup
    public let celsius: Double

    public var id: String { key }

    public init(key: String, name: String, group: SensorGroup, celsius: Double) {
        self.key = key
        self.name = name
        self.group = group
        self.celsius = celsius
    }
}

public struct FanReading: Sendable, Equatable, Identifiable {
    public let id: Int
    public let rpm: Double
    public let minRPM: Double
    public let maxRPM: Double

    public init(id: Int, rpm: Double, minRPM: Double, maxRPM: Double) {
        self.id = id
        self.rpm = rpm
        self.minRPM = minRPM
        self.maxRPM = maxRPM
    }

    /// Where the speed sits between minimum and maximum, 0...1.
    /// A stopped fan is 0. A fan with no reported range is 0.
    public var fraction: Double {
        guard maxRPM > minRPM, rpm.isFinite else { return 0 }
        return min(1, max(0, (rpm - minRPM) / (maxRPM - minRPM)))
    }
}

public struct PowerReading: Sendable, Equatable {
    public let systemWatts: Double?
    /// nil when running on battery.
    public let adapterWatts: Double?
    public let cpuWatts: Double?
    public let gpuWatts: Double?

    public init(systemWatts: Double?, adapterWatts: Double?, cpuWatts: Double?, gpuWatts: Double?) {
        self.systemWatts = systemWatts
        self.adapterWatts = adapterWatts
        self.cpuWatts = cpuWatts
        self.gpuWatts = gpuWatts
    }
}

public struct BatteryReading: Sendable, Equatable {
    /// 0...100
    public let percent: Double
    public let isCharging: Bool
    public let isPluggedIn: Bool
    /// Positive while charging, negative while discharging.
    public let watts: Double
    public let cycleCount: Int
    /// 0...100
    public let healthPercent: Double?
    public let celsius: Double?
    /// The rated output of the connected charger. nil on battery.
    public let adapterWatts: Double?

    public init(percent: Double, isCharging: Bool, isPluggedIn: Bool, watts: Double,
                cycleCount: Int, healthPercent: Double?, celsius: Double?, adapterWatts: Double? = nil) {
        self.percent = percent
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.watts = watts
        self.cycleCount = cycleCount
        self.healthPercent = healthPercent
        self.celsius = celsius
        self.adapterWatts = adapterWatts
    }
}

/// The two figures a process list is sorted by.
public protocol ProcessFigures {
    /// 1.0 is one full core, so this can exceed 1.
    var cpu: Double { get }
    var memoryBytes: UInt64 { get }
}

public struct ProcessReading: Sendable, Equatable, Identifiable, ProcessFigures {
    public let pid: Int32
    public let name: String
    public let cpu: Double
    public let memoryBytes: UInt64

    public var id: Int32 { pid }

    public init(pid: Int32, name: String, cpu: Double, memoryBytes: UInt64) {
        self.pid = pid
        self.name = name
        self.cpu = cpu
        self.memoryBytes = memoryBytes
    }
}

/// An app and the processes that work for it, added up.
public struct ProcessGroup: Sendable, Equatable, Identifiable, ProcessFigures {
    /// Stable for as long as the app runs.
    public let id: String
    public let name: String
    public let cpu: Double
    public let memoryBytes: UInt64
    /// The busiest of its processes. May be fewer than `processCount`.
    public let members: [ProcessReading]
    public let processCount: Int

    public init(id: String, name: String, cpu: Double, memoryBytes: UInt64,
                members: [ProcessReading], processCount: Int) {
        self.id = id
        self.name = name
        self.cpu = cpu
        self.memoryBytes = memoryBytes
        self.members = members
        self.processCount = processCount
    }
}

public enum ProcessOrder: Sendable {
    case cpu
    case memory
}

extension Array where Element: ProcessFigures & Identifiable, Element.ID: Comparable {
    /// The top `limit` entries, highest first. Ties fall back to the other
    /// figure and then the id, so equal rows never swap places.
    public func ranked(by order: ProcessOrder, limit: Int) -> [Element] {
        let ordered = sorted { first, second in
            switch order {
            case .cpu:
                if first.cpu != second.cpu { return first.cpu > second.cpu }
                if first.memoryBytes != second.memoryBytes { return first.memoryBytes > second.memoryBytes }
            case .memory:
                if first.memoryBytes != second.memoryBytes { return first.memoryBytes > second.memoryBytes }
                if first.cpu != second.cpu { return first.cpu > second.cpu }
            }
            return first.id < second.id
        }
        return Array(ordered.prefix(Swift.max(0, limit)))
    }

    /// The top `limit` by CPU together with the top `limit` by memory,
    /// without repeats: enough to show either order.
    public func busiest(limit: Int) -> [Element] {
        var seen = Set<Element.ID>()
        var result: [Element] = []
        for entry in ranked(by: .cpu, limit: limit) + ranked(by: .memory, limit: limit)
        where seen.insert(entry.id).inserted {
            result.append(entry)
        }
        return result
    }
}

/// One app's share of the GPU.
public struct GPUProcessReading: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    /// 0...1 of the whole GPU.
    public let usage: Double

    public init(id: String, name: String, usage: Double) {
        self.id = id
        self.name = name
        self.usage = usage
    }
}

/// Traffic over the network right now.
public struct NetworkReading: Sendable, Equatable {
    public let downloadBytesPerSecond: Double
    public let uploadBytesPerSecond: Double

    public init(downloadBytesPerSecond: Double, uploadBytesPerSecond: Double) {
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
    }
}

/// Everything read at one moment. A nil or empty field means that source
/// was not available.
public struct Snapshot: Sendable, Equatable {
    public let date: Date
    public let cpu: CPUReading?
    public let memory: MemoryReading?
    public let gpu: GPUReading?
    public let temperatures: [TemperatureReading]
    public let fans: [FanReading]
    public let power: PowerReading?
    public let battery: BatteryReading?
    /// The busiest apps. Collected only while a window that lists them is open.
    public let apps: [ProcessGroup]
    /// The apps using the GPU most. Collected along with `apps`.
    public let gpuApps: [GPUProcessReading]
    public let network: NetworkReading?

    public init(date: Date, cpu: CPUReading?, memory: MemoryReading?, gpu: GPUReading?,
                temperatures: [TemperatureReading], fans: [FanReading], power: PowerReading?,
                battery: BatteryReading?, apps: [ProcessGroup], gpuApps: [GPUProcessReading] = [],
                network: NetworkReading? = nil) {
        self.date = date
        self.cpu = cpu
        self.memory = memory
        self.gpu = gpu
        self.temperatures = temperatures
        self.fans = fans
        self.power = power
        self.battery = battery
        self.apps = apps
        self.gpuApps = gpuApps
        self.network = network
    }

    public static let empty = Snapshot(date: Date(timeIntervalSince1970: 0), cpu: nil, memory: nil, gpu: nil,
                                       temperatures: [], fans: [], power: nil, battery: nil, apps: [])

    public var hottest: TemperatureReading? {
        temperatures.max { $0.celsius < $1.celsius }
    }

    public var fastestFan: FanReading? {
        fans.max { $0.rpm < $1.rpm }
    }

    /// The top speed of the fastest fan. nil when no fan reports one.
    public var fanLimit: Double? {
        let highest = fans.map(\.maxRPM).filter { $0.isFinite }.max() ?? 0
        return highest > 0 ? highest : nil
    }
}

/// The few numbers the history graphs need from one snapshot. Keeping
/// these, not whole snapshots, keeps ten minutes of history small.
public struct HistoryPoint: Sendable, Equatable {
    public let date: Date
    /// 0...1
    public let cpu: Double?
    /// 0...1
    public let memory: Double?
    public let hottestCelsius: Double?
    public let systemWatts: Double?
    /// CPU and GPU together.
    public let chipWatts: Double?
    public let fanRPM: Double?
    public let downloadBytesPerSecond: Double?
    public let uploadBytesPerSecond: Double?

    public init(date: Date, cpu: Double? = nil, memory: Double? = nil, hottestCelsius: Double? = nil,
                systemWatts: Double? = nil, chipWatts: Double? = nil, fanRPM: Double? = nil,
                downloadBytesPerSecond: Double? = nil, uploadBytesPerSecond: Double? = nil) {
        self.date = date
        self.cpu = cpu
        self.memory = memory
        self.hottestCelsius = hottestCelsius
        self.systemWatts = systemWatts
        self.chipWatts = chipWatts
        self.fanRPM = fanRPM
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
    }

    public init(_ snapshot: Snapshot) {
        var chip: Double?
        if let power = snapshot.power, power.cpuWatts != nil || power.gpuWatts != nil {
            chip = (power.cpuWatts ?? 0) + (power.gpuWatts ?? 0)
        }
        self.init(date: snapshot.date,
                  cpu: snapshot.cpu?.total,
                  memory: snapshot.memory?.usedFraction,
                  hottestCelsius: snapshot.hottest?.celsius,
                  systemWatts: snapshot.power?.systemWatts,
                  chipWatts: chip,
                  fanRPM: snapshot.fastestFan?.rpm,
                  downloadBytesPerSecond: snapshot.network?.downloadBytesPerSecond,
                  uploadBytesPerSecond: snapshot.network?.uploadBytesPerSecond)
    }
}
