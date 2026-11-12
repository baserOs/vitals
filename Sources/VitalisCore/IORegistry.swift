import Foundation
import IOKit

/// Small helpers for reading properties from the I/O Registry.
enum IORegistry {
    /// Calls `body` with each service of the given class.
    static func forEachService(named className: String, _ body: (io_service_t) -> Void) {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(className), &iterator) == KERN_SUCCESS else {
            return
        }
        defer { IOObjectRelease(iterator) }
        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            body(service)
            IOObjectRelease(service)
        }
    }

    /// Calls `body` with each entry directly below `service`.
    static func forEachChild(of service: io_service_t, _ body: (io_registry_entry_t) -> Void) {
        var iterator: io_iterator_t = 0
        guard IORegistryEntryGetChildIterator(service, kIOServicePlane, &iterator) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }
        while true {
            let child = IOIteratorNext(iterator)
            if child == 0 { break }
            body(child)
            IOObjectRelease(child)
        }
    }

    static func property(_ name: String, of service: io_service_t) -> Any? {
        guard let value = IORegistryEntryCreateCFProperty(service, name as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        return value.takeRetainedValue()
    }

    static func properties(of service: io_service_t) -> [String: Any]? {
        var unmanaged: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dictionary = unmanaged?.takeRetainedValue() else { return nil }
        return (dictionary as NSDictionary) as? [String: Any]
    }

    static func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }
}
