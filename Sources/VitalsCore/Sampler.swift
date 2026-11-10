import Combine
import Foundation

/// Polls every source on a background queue and publishes the result.
/// Create it and read its published values on the main thread.
public final class Sampler: ObservableObject {
    @Published public private(set) var latest: Snapshot = .empty
    /// Oldest first. Covers the last `historySeconds` seconds.
    @Published public private(set) var history: [Snapshot] = []

    public static let historySeconds: TimeInterval = 600
    public static let allowedIntervals: [TimeInterval] = [1, 2, 5]
    static let processLimit = 15

    /// Seconds between samples. Changing it restarts sampling.
    public var interval: TimeInterval {
        didSet {
            guard interval != oldValue else { return }
            var resized = RingBuffer<Snapshot>(capacity: Sampler.historyCapacity(interval: interval))
            for snapshot in ring.elements { resized.append(snapshot) }
            ring = resized
            if timer != nil { startTimer() }
        }
    }

    /// Whether to collect the process list, which is the most expensive
    /// source. Turn it on only while a window that shows processes is open.
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
    private var ring: RingBuffer<Snapshot>

    // Used only on `queue`.
    private var sources: Sources?
    private var collectsProcesses = false

    public init(interval: TimeInterval = 2) {
        self.interval = interval
        self.ring = RingBuffer<Snapshot>(capacity: Sampler.historyCapacity(interval: interval))
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
        let snapshot = Snapshot(
            date: Date(),
            cpu: sources.cpu.read(),
            memory: sources.memory.read(),
            gpu: sources.gpu.read(),
            temperatures: sources.temperature.read(),
            fans: sources.fan.read(),
            power: sources.power.read(interval: interval),
            battery: sources.battery.read(),
            processes: collectsProcesses ? sources.process.read(limit: Sampler.processLimit) : []
        )
        DispatchQueue.main.async { [weak self] in
            self?.publish(snapshot)
        }
    }

    // Runs on the main thread.
    private func publish(_ snapshot: Snapshot) {
        ring.append(snapshot)
        latest = snapshot
        history = ring.elements
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
    let process = ProcessSource()
    let temperature: TemperatureSource
    let fan: FanSource
    let power: PowerSource

    init() {
        let smc = SMCClient()
        temperature = TemperatureSource(smc: smc)
        fan = FanSource(smc: smc)
        power = PowerSource(smc: smc)
    }
}
