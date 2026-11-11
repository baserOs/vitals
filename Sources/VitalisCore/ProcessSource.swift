import Darwin
import Foundation

/// The busiest processes. Without root, macOS only reports usage for the
/// current user's own processes, so system processes are not listed.
public final class ProcessSource {
    private var previousCPUTime: [Int32: UInt64] = [:]
    private var previousUptime: UInt64 = 0
    private let timebaseNumerator: UInt64
    private let timebaseDenominator: UInt64

    public init() {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        timebaseNumerator = UInt64(max(1, timebase.numer))
        timebaseDenominator = UInt64(max(1, timebase.denom))
    }

    /// The top `limit` processes by CPU plus the top `limit` by memory,
    /// without repeats. CPU is measured between two calls.
    public func read(limit: Int) -> [ProcessReading] {
        let estimated = Int(proc_listallpids(nil, 0))
        guard estimated > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: estimated + 64)
        let listed = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.stride)))
        guard listed > 0 else { return [] }

        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = previousUptime > 0 && now > previousUptime ? Double(now - previousUptime) : 0
        var cpuTimes: [Int32: UInt64] = [:]
        cpuTimes.reserveCapacity(listed)
        var readings: [ProcessReading] = []
        readings.reserveCapacity(listed)

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
            readings.append(ProcessReading(pid: pid, name: ProcessSource.name(of: pid), cpu: cpu,
                                           memoryBytes: usage.ri_phys_footprint))
        }
        previousCPUTime = cpuTimes
        previousUptime = now

        let byCPU = readings.sorted { $0.cpu > $1.cpu }.prefix(limit)
        let byMemory = readings.sorted { $0.memoryBytes > $1.memoryBytes }.prefix(limit)
        var seen = Set<Int32>()
        var result: [ProcessReading] = []
        for reading in Array(byCPU) + Array(byMemory) where !seen.contains(reading.pid) {
            seen.insert(reading.pid)
            result.append(reading)
        }
        return result
    }

    private static func name(of pid: pid_t) -> String {
        var buffer = [UInt8](repeating: 0, count: 256)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return "pid \(pid)" }
        let name = String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        return name.isEmpty ? "pid \(pid)" : name
    }
}
