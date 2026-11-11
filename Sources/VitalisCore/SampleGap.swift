import Foundation

public enum SampleGap {
    /// Whether a change measured over `elapsed` seconds can be trusted when
    /// samples are meant to be `interval` seconds apart. A much longer gap
    /// means sampling was paused, and the change would show as a false spike.
    public static func isUsable(elapsed: TimeInterval, interval: TimeInterval) -> Bool {
        elapsed > 0 && elapsed <= interval * 3
    }
}
