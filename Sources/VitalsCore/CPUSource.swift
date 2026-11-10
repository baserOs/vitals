import Darwin
import Foundation

/// Per-core and total CPU usage.
public final class CPUSource {
    private let host = mach_host_self()
    private let performanceCount: Int
    private let efficiencyCount: Int
    private var previous: [CPUTicks] = []

    public init() {
        performanceCount = Sysctl.int("hw.perflevel0.logicalcpu") ?? 0
        efficiencyCount = Sysctl.int("hw.perflevel1.logicalcpu") ?? 0
    }

    /// Usage is measured between two calls, so the first call reports 0.
    public func read() -> CPUReading? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        guard result == KERN_SUCCESS, let info = info else { return nil }
        defer {
            let size = vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)
            _ = vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), size)
        }

        let statesPerCore = Int(CPU_STATE_MAX)
        let count = Int(cpuCount)
        guard count > 0, Int(infoCount) >= count * statesPerCore else { return nil }

        var current: [CPUTicks] = []
        current.reserveCapacity(count)
        for core in 0..<count {
            let base = core * statesPerCore
            current.append(CPUTicks(
                user: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)])),
                system: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)])),
                idle: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)])),
                nice: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
            ))
        }

        let comparable = previous.count == current.count
        // Apple Silicon lists efficiency cores first.
        let kindsKnown = efficiencyCount + performanceCount == count
        var cores: [CoreReading] = []
        cores.reserveCapacity(count)
        var busyTotal = 0.0
        for core in 0..<count {
            let usage = comparable ? CPUMath.usage(previous: previous[core], current: current[core]) : 0
            let kind: CoreKind = (kindsKnown && core < efficiencyCount) ? .efficiency : .performance
            cores.append(CoreReading(id: core, usage: usage, kind: kind))
            busyTotal += usage
        }
        previous = current

        var loads = [Double](repeating: 0, count: 3)
        let loadCount = getloadavg(&loads, 3)
        let loadAverage = loadCount > 0 ? Array(loads.prefix(Int(loadCount))) : []

        return CPUReading(total: busyTotal / Double(count), cores: cores, loadAverage: loadAverage)
    }
}
