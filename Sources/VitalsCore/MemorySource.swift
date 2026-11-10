import Darwin
import Foundation

/// Memory use, counted the way Activity Monitor counts it.
public final class MemorySource {
    private let host: mach_port_t
    private let pageSize: UInt64

    public init() {
        let port = mach_host_self()
        host = port
        var size: vm_size_t = 0
        if host_page_size(port, &size) == KERN_SUCCESS, size > 0 {
            pageSize = UInt64(size)
        } else {
            pageSize = 16384
        }
    }

    public func read() -> MemoryReading? {
        var stats = vm_statistics64_data_t()
        let capacity = MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        var count = mach_msg_type_number_t(capacity)
        let port = host
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) { rebound in
                host_statistics64(port, HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let total = ProcessInfo.processInfo.physicalMemory
        let internalPages = UInt64(stats.internal_page_count)
        let purgeable = UInt64(stats.purgeable_count)
        let appPages = internalPages > purgeable ? internalPages - purgeable : 0
        let app = appPages * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let cached = (purgeable + UInt64(stats.external_page_count)) * pageSize
        let used = min(total, app + wired + compressed)
        let remaining = total - used
        let shownCached = min(cached, remaining)
        let free = remaining - shownCached

        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        let hasSwap = sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0

        let pressure: MemoryPressure
        switch Sysctl.int("kern.memorystatus_vm_pressure_level") ?? 1 {
        case 4: pressure = .critical
        case 2: pressure = .warning
        default: pressure = .normal
        }

        return MemoryReading(
            total: total, used: used, wired: wired, compressed: compressed, cached: shownCached, free: free,
            swapUsed: hasSwap ? swap.xsu_used : 0, swapTotal: hasSwap ? swap.xsu_total : 0, pressure: pressure
        )
    }
}
