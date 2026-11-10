import AppKit
import SwiftUI
import VitalsCore

/// The window that opens from the menu bar item.
struct PopoverView: View {
    @ObservedObject private var visibility = PopoverVisibility.shared

    var body: some View {
        VStack(spacing: 0) {
            if visibility.isVisible {
                PopoverContent()
            } else {
                // Closed: draw nothing, so a hidden popover costs nothing.
                Color.clear
            }
            Divider()
            PopoverFooter()
        }
        .frame(width: 340, height: 640)
        .background(WindowVisibilityReporter { visible in
            PopoverVisibility.shared.isVisible = visible
        })
        .onAppear {
            PopoverVisibility.shared.hasAppeared = true
            PopoverVisibility.shared.isVisible = true
        }
    }
}

/// The readings. Kept apart from PopoverView so that only this part is
/// redrawn on every sample.
struct PopoverContent: View {
    @EnvironmentObject private var sampler: Sampler
    @AppStorage(SettingsKey.temperatureUnit) private var unit: TemperatureUnit = .celsius

    var body: some View {
        let snapshot = sampler.latest
        ScrollView {
            VStack(spacing: 8) {
                CPUSection(snapshot: snapshot)
                GPUSection(snapshot: snapshot)
                MemorySection(snapshot: snapshot)
                TemperaturesSection(snapshot: snapshot, unit: unit, rowLimit: 4)
                FansSection(snapshot: snapshot)
                PowerSection(snapshot: snapshot)
                BatterySection(snapshot: snapshot, unit: unit)
                ProcessesSection(snapshot: snapshot, limit: 5)
            }
            .padding(10)
        }
    }
}

struct PopoverFooter: View {
    @EnvironmentObject private var sampler: Sampler

    var body: some View {
        HStack {
            Button("Dashboard") {
                AppWindows.openDashboard(sampler: sampler)
            }
            Button("Settings") {
                AppWindows.openSettings(sampler: sampler)
            }
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(10)
    }
}
