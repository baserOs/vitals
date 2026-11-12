import Darwin
import Foundation

/// The busiest apps, each with the processes that work for it. Without
/// root, macOS only reports usage for the current user's own processes, so
/// system processes are not listed.
public final class ProcessSource {
    /// Most processes kept per app for each order.
    static let memberLimit = 6

    private var previousCPUTime: [Int32: UInt64] = [:]
    private var previousUptime: UInt64 = 0
    private let timebaseNumerator: UInt64
    private let timebaseDenominator: UInt64
    private let resolver: AppResolver

    public convenience init() {
        self.init(resolver: AppResolver())
    }

    init(resolver: AppResolver) {
        self.resolver = resolver
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        timebaseNumerator = UInt64(max(1, timebase.numer))
        timebaseDenominator = UInt64(max(1, timebase.denom))
    }

    /// The top `limit` apps by CPU together with the top `limit` by memory,
    /// without repeats. CPU is measured between two calls.
    public func read(limit: Int) -> [ProcessGroup] {
        let estimated = Int(proc_listallpids(nil, 0))
        guard estimated > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: estimated + 64)
        let listed = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.stride)))
        guard listed > 0 else { return [] }

        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = previousUptime > 0 && now > previousUptime ? Double(now - previousUptime) : 0
        var cpuTimes: [Int32: UInt64] = [:]
        cpuTimes.reserveCapacity(listed)
        var gathered: [AppIdentity: [ProcessReading]] = [:]

        for pid in pids.prefix(min(listed, pids.count)) where pid > 0 {
            var usage = rusage_info_v4()
            let status = withUnsafeMutablePointer(to: &usage) { pointer in
                pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, rebound)
                }
            }
            // Fails for other users' processes and for ones that just exited.
            guard status == 0 else { continue }

            let ticks = usage.ri_user_time &+ usage.ri_system_time
            let cpuTime = ticks / timebaseDenominator * timebaseNumerator
                + (ticks % timebaseDenominator) * timebaseNumerator / timebaseDenominator
            cpuTimes[pid] = cpuTime

            var cpu = 0.0
            if elapsed > 0, let before = previousCPUTime[pid], cpuTime >= before {
                cpu = Double(cpuTime - before) / elapsed
            }
            let name = AppResolver.name(of: pid) ?? "pid \(pid)"
            let reading = ProcessReading(pid: pid, name: name, cpu: cpu, memoryBytes: usage.ri_phys_footprint)
            gathered[resolver.identity(pid: pid, name: name), default: []].append(reading)
        }
        previousCPUTime = cpuTimes
        previousUptime = now

        return ProcessSource.groups(from: gathered).busiest(limit: limit)
    }

    /// Adds up each app's processes and keeps its busiest ones.
    static func groups(from gathered: [AppIdentity: [ProcessReading]]) -> [ProcessGroup] {
        gathered.map { identity, processes in
            ProcessGroup(
                id: identity.key,
                name: identity.name,
                cpu: processes.reduce(0) { $0 + $1.cpu },
                memoryBytes: processes.reduce(0) { $0 &+ $1.memoryBytes },
                members: processes.busiest(limit: memberLimit),
                processCount: processes.count
            )
        }
    }
}
