import Foundation

/// Keeps the most recent `capacity` elements.
public struct RingBuffer<Element> {
    public let capacity: Int
    private var storage: [Element] = []
    private var start = 0

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
        storage.reserveCapacity(self.capacity)
    }

    public var count: Int { storage.count }

    public mutating func append(_ element: Element) {
        if storage.count < capacity {
            storage.append(element)
        } else {
            storage[start] = element
            start = (start + 1) % capacity
        }
    }

    /// Oldest first.
    public var elements: [Element] {
        guard start > 0 else { return storage }
        return Array(storage[start...]) + Array(storage[..<start])
    }
}
