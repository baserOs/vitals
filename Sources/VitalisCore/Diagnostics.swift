import CVitalis
import Foundation

/// A plain-text dump of everything this Mac lets the app read. Sensor keys
/// differ between chip generations, so this report is how the sensor names
/// get filled in. It contains no serial numbers, user names or file paths.
///
/// Not thread safe with sampling: run it on the sampling queue.
public enum Diagnostics {
    public static func report() -> String {
        var lines: [String] = []
        func section(_ title: String) {
            lines.append("")
            lines.append("== \(title) ==")
        }

        lines.append("Vitalis diagnostics")
        lines.append("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        lines.append("Model: \(Sysctl.string("hw.model") ?? "unknown")")
        lines.append("Chip: \(Sysctl.string("machdep.cpu.brand_string") ?? "unknown")")
        lines.append("Cores: \(Sysctl.int("hw.perflevel0.logicalcpu") ?? 0) performance, "
            + "\(Sysctl.int("hw.perflevel1.logicalcpu") ?? 0) efficiency")

        let smc = SMCClient()
        section("SMC keys (T, F, P)")
        if let smc = smc {
            let keys = smc.allKeys()
            lines.append("Total keys: \(keys.count)")
            for key in keys where key.hasPrefix("T") || key.hasPrefix("F") || key.hasPrefix("P") {
                guard let raw = smc.rawRead(key) else {
                    lines.append("\(key)  unreadable")
                    continue
                }
                if let value = SMCDecode.value(type: raw.type, bytes: raw.bytes) {
                    lines.append("\(key)  [\(raw.type)]  \(String(format: "%.3f", value))")
                } else {
                    let hex = raw.bytes.map { String(format: "%02x", $0) }.joined()
                    lines.append("\(key)  [\(raw.type)]  0x\(hex)")
                }
            }
        } else {
            lines.append("SMC: not available")
        }

        section("HID temperature sensors")
        let hid = HIDSensors.read()
        if hid.isEmpty { lines.append("none") }
        for sensor in hid {
            lines.append("\(sensor.name)  \(String(format: "%.2f", sensor.celsius))")
        }

        // Everything below is measured between two samples one second apart.
        let cpu = CPUSource()
        let power = PowerSource(smc: smc)
        let resolver = AppResolver()
        let processes = ProcessSource(resolver: resolver)
        let network = NetworkSource()
        let gpu = GPUSource()
        _ = cpu.read()
        _ = EnergyCounters.sample()
        _ = processes.read(limit: 5)
        _ = network.read(interval: 1)
        _ = gpu.readApps(utilization: 0, interval: 1, resolver: resolver, limit: 5)
        Thread.sleep(forTimeInterval: 1)

        section("Energy counters (change over about one second)")
        let energy = EnergyCounters.sample()
        if energy.channels.isEmpty { lines.append("none") }
        lines.append("Elapsed: \(String(format: "%.3f", energy.elapsed)) s")
        for channel in energy.channels {
            lines.append("\(channel.name)  [\(channel.unit)]  \(String(format: "%.0f", channel.delta))")
        }

        section("CPU")
        if let reading = cpu.read() {
            lines.append("Total: \(Format.percent(reading.total))")
            lines.append("Load average: " + reading.loadAverage.map { String(format: "%.2f", $0) }.joined(separator: " "))
            for core in reading.cores {
                lines.append("Core \(core.id) (\(core.kind.rawValue)): \(Format.percent(core.usage))")
            }
        } else {
            lines.append("not available")
        }

        section("Memory")
        if let reading = MemorySource().read() {
            lines.append("Total: \(Format.bytes(reading.total))")
            lines.append("Used: \(Format.bytes(reading.used)) (app \(Format.bytes(reading.app)), "
                + "wired \(Format.bytes(reading.wired)), compressed \(Format.bytes(reading.compressed)))")
            lines.append("Cached: \(Format.bytes(reading.cached))  Free: \(Format.bytes(reading.free))")
            lines.append("Swap: \(Format.bytes(reading.swapUsed)) of \(Format.bytes(reading.swapTotal))")
            lines.append("Pressure: \(reading.pressure.rawValue)")
        } else {
            lines.append("not available")
        }

        section("GPU")
        lines.append(GPUSource().read().map { "Usage: \(Format.percent($0.usage))" } ?? "not available")

        section("Temperatures (as the app shows them)")
        let temperatures = TemperatureSource(smc: smc).read()
        if temperatures.isEmpty { lines.append("none") }
        for reading in temperatures {
            lines.append("\(reading.key)  \(reading.group.rawValue)  \(String(format: "%.1f", reading.celsius))")
        }

        section("Fans")
        let fans = FanSource(smc: smc).read()
        if fans.isEmpty { lines.append("none") }
        for fan in fans {
            lines.append("Fan \(fan.id): \(Format.rpm(fan.rpm)) (min \(Format.rpm(fan.minRPM)), max \(Format.rpm(fan.maxRPM)))")
        }

        section("Power")
        // The energy counters were just sampled above, so sample once more
        // over a short wait to give this reading its own time span.
        Thread.sleep(forTimeInterval: 0.5)
        if let reading = power.read(interval: 1) {
            lines.append("System: \(Format.watts(reading.systemWatts))")
            lines.append("Adapter: \(Format.watts(reading.adapterWatts))")
            lines.append("CPU: \(Format.watts(reading.cpuWatts))")
            lines.append("GPU: \(Format.watts(reading.gpuWatts))")
        } else {
            lines.append("not available")
        }

        section("Battery")
        if let reading = BatterySource().read() {
            lines.append("Charge: \(String(format: "%.0f", reading.percent))%")
            lines.append("Charging: \(reading.isCharging)  Plugged in: \(reading.isPluggedIn)")
            lines.append("Power: \(Format.watts(reading.watts))")
            lines.append("Cycles: \(reading.cycleCount)")
            let health = reading.healthPercent.map { String(format: "%.0f%%", $0) } ?? Format.missing
            lines.append("Health: \(health)")
            lines.append("Temperature: \(Format.temperature(reading.celsius, unit: .celsius))")
            lines.append("Charger rating: \(Format.watts(reading.adapterWatts))")
        } else {
            lines.append("not available")
        }

        section("Limits used for the graph scales")
        let limits = MachineLimits.detect(adapterWatts: BatterySource().read()?.adapterWatts)
        lines.append("GPU cores: \(MachineLimits.gpuCoreCount().map(String.init) ?? "unknown")")
        lines.append("CPU + GPU (estimate): \(Format.watts(limits.chipWatts))")
        lines.append("System: \(Format.watts(limits.systemWatts))"
            + (limits.systemIsEstimate ? " (estimate, no charger seen)" : " (charger rating)"))

        section("Network (over about one and a half seconds)")
        if let reading = network.read(interval: 2) {
            lines.append("Download: \(Format.bitRate(bytesPerSecond: reading.downloadBytesPerSecond))")
            lines.append("Upload: \(Format.bitRate(bytesPerSecond: reading.uploadBytesPerSecond))")
        } else {
            lines.append("not available")
        }
        lines.append("Interfaces: " + NetworkSource.counters().keys.sorted().joined(separator: " "))

        section("GPU by app")
        let clients = gpu.readClients()
        lines.append("Connections to the GPU: \(clients.count)")
        lines.append("Lookup of the app a process works for: "
            + (vitalis_responsible_pid(getpid()) > 0 ? "available" : "not available"))
        let gpuUsage = gpu.read()?.usage ?? 0
        let gpuApps = gpu.readApps(utilization: gpuUsage, interval: 2, resolver: resolver, limit: 5)
        if gpuApps.isEmpty { lines.append("none active") }
        for app in gpuApps {
            lines.append("\(app.name)  \(Format.percent(app.usage))")
        }

        section("Top apps")
        let top = processes.read(limit: 5)
        if top.isEmpty { lines.append("none") }
        for app in top {
            lines.append("\(app.name) (\(app.processCount))  \(Format.percent(app.cpu))  \(Format.bytes(app.memoryBytes))")
        }

        return lines.joined(separator: "\n") + "\n"
    }
}
