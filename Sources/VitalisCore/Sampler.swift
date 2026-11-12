import Combine
import Foundation

/// Polls every source on a background queue and publishes the result.
/// Create it and read its published values on the main thread.
public final class Sampler: ObservableObject {
    @Published public private(set) var latest: Snapshot = .empty

    /// Oldest first. Covers the last `historySeconds` seconds. Built when
    /// asked for, so it costs nothing while no graph is on screen. Read it
    /// on the main thread, where `latest` changes along with it.
    public var history: [HistoryPoint] { ring.elements }

    /// The most this Mac can draw, used as the top of the power graphs.
    @Published public private(set) var limits: MachineLimits

    public static let historySeconds: TimeInterval = 600
    public static let allowedIntervals: [TimeInterval] = [1, 2, 5]
    static let processLimit = 20
    static let gpuAppLimit = 5

    /// Seconds between samples. Changing it restarts sampling.
    public var interval: TimeInterval {
        didSet {
            guard interval != oldValue else { return }
            var resized = RingBuffer<HistoryPoint>(capacity: Sampler.historyCapacity(interval: interval))
            for point in ring.elements { resized.append(point) }
            ring = resized
            if timer != nil { startTimer() }
        }
    }

    /// Whether to collect the app lists (processes and GPU use), which are
    /// the most expensive sources. Turn it on only while a window that
    /// shows them is open.
    public var wantsProcesses = false {
        didSet {
            guard wantsProcesses != oldValue else { return }
            let enabled = wantsProcesses
            let interval = self.interval
            queue.async { [weak self] in
                guard let self = self else { return }
                self.collectsProcesses = enabled
                // Sample at once so the list does not wait for the next tick.
                if enabled { self.sample(interval: interval) }
            }
        }
    }

    /// Called on the main thread after each sample. Return true while any
    /// window that shows processes is visible.
    public var visibilityCheck: (() -> Bool)?

    private let queue = DispatchQueue(label: "local.vitals.sampler", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var ring: RingBuffer<HistoryPoint>

    // Used only on `queue`.
    private var sources: Sources?
    private var collectsProcesses = false

    /// Where the rating of the biggest charger seen is remembered, so the
    /// system power scale is right on battery too.
    static let adapterWattsKey = "largestAdapterWatts"

    public init(interval: TimeInterval = 2) {
        self.interval = interval
        let remembered = UserDefaults.standard.double(forKey: Sampler.adapterWattsKey)
        self.limits = MachineLimits.detect(adapterWatts: remembered > 0 ? remembered : nil)
        self.ring = RingBuffer<HistoryPoint>(capacity: Sampler.historyCapacity(interval: interval))
    }

    public static func historyCapacity(interval: TimeInterval) -> Int {
        guard interval > 0 else { return Int(historySeconds) }
        return max(1, Int((historySeconds / interval).rounded()))
    }

    public func start() {
        guard timer == nil else { return }
        startTimer()
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    /// Builds the diagnostics report on the sampling queue, so it never runs
    /// at the same time as a sample, and delivers it on the main thread.
    public func runDiagnostics(completion: @escaping (String) -> Void) {
        queue.async {
            let report = Diagnostics.report()
            DispatchQueue.main.async { completion(report) }
        }
    }

    private func startTimer() {
        timer?.cancel()
        let interval = self.interval
        let newTimer = DispatchSource.makeTimerSource(queue: queue)
        newTimer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(Int(interval * 100)))
        newTimer.setEventHandler { [weak self] in
            self?.sample(interval: interval)
        }
        newTimer.resume()
        timer = newTimer
    }

    // Runs on `queue`.
    private func sample(interval: TimeInterval) {
        if sources == nil { sources = Sources() }
        guard let sources = sources else { return }
        let gpu = sources.gpu.read()
        var apps: [ProcessGroup] = []
        var gpuApps: [GPUProcessReading] = []
        if collectsProcesses {
            apps = sources.process.read(limit: Sampler.processLimit)
            gpuApps = sources.gpu.readApps(utilization: gpu?.usage ?? 0, interval: interval,
                                           resolver: sources.resolver, limit: Sampler.gpuAppLimit)
        }
        let snapshot = Snapshot(
            date: Date(),
            cpu: sources.cpu.read(),
            memory: sources.memory.read(),
            gpu: gpu,
            temperatures: sources.temperature.read(),
            fans: sources.fan.read(),
            power: sources.power.read(interval: interval),
            battery: sources.battery.read(),
            apps: apps,
            gpuApps: gpuApps,
            network: sources.network.read(interval: interval)
        )
        DispatchQueue.main.async { [weak self] in
            self?.publish(snapshot)
        }
    }

    /// Shows fixed data without sampling. For tests and previews.
    func load(latest: Snapshot, history: [HistoryPoint], limits: MachineLimits) {
        var filled = RingBuffer<HistoryPoint>(capacity: max(1, history.count))
        for point in history { filled.append(point) }
        ring = filled
        self.limits = limits
        self.latest = latest
    }

    // Runs on the main thread.
    private func publish(_ snapshot: Snapshot) {
        ring.append(HistoryPoint(snapshot))
        latest = snapshot
        if let rated = snapshot.battery?.adapterWatts, rated > (limits.adapterWatts ?? 0) {
            limits.adapterWatts = rated
            UserDefaults.standard.set(rated, forKey: Sampler.adapterWattsKey)
        }
        if let visibilityCheck = visibilityCheck {
            wantsProcesses = visibilityCheck()
        }
    }
}

/// One of each source, sharing one SMC connection.
final class Sources {
    let cpu = CPUSource()
    let memory = MemorySource()
    let gpu = GPUSource()
    let battery = BatterySource()
    let network = NetworkSource()
    /// Shared, so the process list and the GPU list name apps the same way.
    let resolver: AppResolver
    let process: ProcessSource
    let temperature: TemperatureSource
    let fan: FanSource
    let power: PowerSource

    init() {
        let shared = AppResolver()
        resolver = shared
        process = ProcessSource(resolver: shared)
        let smc = SMCClient()
        temperature = TemperatureSource(smc: smc)
        fan = FanSource(smc: smc)
        power = PowerSource(smc: smc)
    }
}
