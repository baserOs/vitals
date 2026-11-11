import AppKit
import SwiftUI
import VitalisCore

@main
struct VitalisApp: App {
    @StateObject private var sampler: Sampler
    @AppStorage(SettingsKey.menuBarFields) private var fieldsText = SettingsDefault.menuBarFields
    @AppStorage(SettingsKey.temperatureUnit) private var unit: TemperatureUnit = .celsius

    init() {
        let sampler = Sampler(interval: SettingsDefault.storedRefreshInterval)
        // Collect the process list only while something that shows it is open.
        // The sampler calls this on the main thread.
        sampler.visibilityCheck = {
            MainActor.assumeIsolated {
                PopoverVisibility.shared.isOpen || WindowManager.shared.hasVisibleWindow
            }
        }
        sampler.start()
        _sampler = StateObject(wrappedValue: sampler)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(sampler)
        } label: {
            let fields = MenuBarField.parse(fieldsText)
            if fields.isEmpty {
                // Never leave the menu bar item empty, or it cannot be clicked.
                Image(systemName: "cpu")
            } else {
                Text(Format.menuBar(sampler.latest, fields: fields, unit: unit))
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)
    }
}

/// Opens the app's secondary windows.
@MainActor
enum AppWindows {
    static func openDashboard(sampler: Sampler) {
        WindowManager.shared.show(id: "dashboard", title: "Vitalis",
                                  size: NSSize(width: 920, height: 720),
                                  minSize: NSSize(width: 820, height: 600)) {
            DashboardView()
                .environmentObject(sampler)
        }
    }

    static func openSettings(sampler: Sampler) {
        WindowManager.shared.show(id: "settings", title: "Vitalis Settings",
                                  size: NSSize(width: 420, height: 490), minSize: nil) {
            SettingsView()
                .environmentObject(sampler)
        }
    }
}
