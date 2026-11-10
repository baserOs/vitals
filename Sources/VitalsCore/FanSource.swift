import Foundation

/// Fan speeds. Read only: this app never changes them.
public final class FanSource {
    private let smc: SMCClient?

    public init(smc: SMCClient?) {
        self.smc = smc
    }

    public func read() -> [FanReading] {
        guard let smc = smc, let countValue = smc.read("FNum")?.value else { return [] }
        let count = Int(countValue)
        guard count > 0, count <= 16 else { return [] }
        var fans: [FanReading] = []
        for index in 0..<count {
            guard let rpm = smc.read("F\(index)Ac")?.value, rpm.isFinite, rpm >= 0 else { continue }
            let minimum = smc.read("F\(index)Mn")?.value ?? 0
            let maximum = smc.read("F\(index)Mx")?.value ?? 0
            fans.append(FanReading(id: index, rpm: rpm, minRPM: minimum, maxRPM: maximum))
        }
        return fans
    }
}
