import XCTest
@testable import VitalsCore

final class FormatTests: XCTestCase {
    func testTemperature() {
        XCTAssertEqual(Format.temperature(50, unit: .celsius), "50°C")
        XCTAssertEqual(Format.temperature(50, unit: .fahrenheit), "122°F")
        XCTAssertEqual(Format.temperature(nil, unit: .celsius), Format.missing)
    }

    // Review Focus 3: a missing value is a dash, never a zero.
    func testWatts() {
        XCTAssertEqual(Format.watts(12.34), "12.3 W")
        XCTAssertEqual(Format.watts(nil), Format.missing)
        XCTAssertNotEqual(Format.watts(nil), Format.watts(0))
    }

    func testPercent() {
        XCTAssertEqual(Format.percent(0.156), "16%")
        XCTAssertEqual(Format.percent(1.5), "150%")
        XCTAssertEqual(Format.percent(nil), Format.missing)
    }

    func testBytes() {
        XCTAssertEqual(Format.bytes(8_589_934_592), "8.0 GB")
        XCTAssertEqual(Format.bytes(1_572_864), "1.5 MB")
        XCTAssertEqual(Format.bytes(512), "512 B")
    }

    func testRPM() {
        XCTAssertEqual(Format.rpm(0), "0 rpm")
        XCTAssertEqual(Format.rpm(2150.4), "2150 rpm")
        XCTAssertEqual(Format.rpm(nil), Format.missing)
    }

    func testMenuBarJoinsChosenFields() {
        let snapshot = Snapshot(
            date: Date(), cpu: nil, memory: nil, gpu: nil,
            temperatures: [
                TemperatureReading(key: "Tp01", name: "Tp01", group: .cpu, celsius: 62),
                TemperatureReading(key: "TB1T", name: "Battery 1", group: .battery, celsius: 31),
            ],
            fans: [FanReading(id: 0, rpm: 0, minRPM: 1200, maxRPM: 6000)],
            power: PowerReading(systemWatts: 14.2, adapterWatts: nil, cpuWatts: nil, gpuWatts: nil),
            battery: nil, processes: []
        )
        XCTAssertEqual(Format.menuBar(snapshot, fields: [.temperature, .watts], unit: .celsius), "62°C  14.2 W")
        XCTAssertEqual(Format.menuBar(snapshot, fields: [.fan], unit: .celsius), "0 rpm")
        XCTAssertEqual(Format.menuBar(snapshot, fields: [.cpu, .memory], unit: .celsius),
                       "\(Format.missing)  \(Format.missing)")
    }

    func testMenuBarWithNoDataShowsDashes() {
        XCTAssertEqual(Format.menuBar(.empty, fields: [.temperature, .watts], unit: .celsius),
                       "\(Format.missing)  \(Format.missing)")
    }

    func testMenuBarWithNoFieldsIsEmpty() {
        XCTAssertEqual(Format.menuBar(.empty, fields: [], unit: .celsius), "")
    }
}

final class MenuBarFieldTests: XCTestCase {
    func testParse() {
        XCTAssertEqual(MenuBarField.parse("temperature,watts"), [.temperature, .watts])
        XCTAssertEqual(MenuBarField.parse(""), [])
        XCTAssertEqual(MenuBarField.parse("bogus, cpu"), [.cpu])
    }

    func testParseUsesDisplayOrderAndDropsRepeats() {
        XCTAssertEqual(MenuBarField.parse("watts,cpu,watts"), [.cpu, .watts])
    }

    func testSerializeRoundTrips() {
        XCTAssertEqual(MenuBarField.serialize([.watts, .cpu]), "cpu,watts")
        XCTAssertEqual(MenuBarField.parse(MenuBarField.serialize(MenuBarField.allCases)), MenuBarField.allCases)
    }
}
