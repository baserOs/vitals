import AppKit
import SwiftUI
import VitalisCore

/// The window that opens from the menu bar item. Drawn as Liquid Glass:
/// the system's translucent panel behind, a denser glass card per section.
struct PopoverView: View {
    @ObservedObject private var visibility = PopoverVisibility.shared
    @AppStorage(SettingsKey.popoverTransparency) private var transparency = SettingsDefault.popoverTransparency

    var body: some View {
        VStack(spacing: 0) {
            if visibility.isVisible {
                PopoverContent()
            } else {
                // Closed: draw nothing, so a hidden popover costs nothing.
                Color.clear
            }
            PopoverFooter()
        }
        .frame(width: 340, height: 640)
        .background(WindowVisibilityReporter(
            backdropOpacity: 1 - SettingsDefault.clampedTransparency(transparency)
        ) { visible in
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
    var body: some View {
        ScrollView {
            PopoverSections()
        }
        .scrollIndicators(.hidden)
    }
}

/// The cards of the popover, without the scrolling around them.
struct PopoverSections: View {
    @EnvironmentObject private var sampler: Sampler
    @AppStorage(SettingsKey.temperatureUnit) private var unit: TemperatureUnit = .celsius

    var body: some View {
        let snapshot = sampler.latest
        VStack(spacing: 10) {
            CPUSection(snapshot: snapshot)
            GPUSection(snapshot: snapshot)
            MemorySection(snapshot: snapshot)
            TemperaturesSection(snapshot: snapshot, unit: unit)
            FansSection(snapshot: snapshot, showsRange: false)
            PowerSection(snapshot: snapshot, limits: sampler.limits)
            BatterySection(snapshot: snapshot, unit: unit)
            ProcessesSection(snapshot: snapshot, limit: 5, sortByMemory: true)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .environment(\.cardStyle, .glass)
    }
}

struct PopoverFooter: View {
    @EnvironmentObject private var sampler: Sampler

    var body: some View {
        HStack(spacing: 8) {
            Button {
                AppWindows.openDashboard(sampler: sampler)
            } label: {
                Label("Dashboard", systemImage: "chart.xyaxis.line")
            }
            Button {
                AppWindows.openSettings(sampler: sampler)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
        }
        .labelStyle(.titleAndIcon)
        .modifier(PillButtonStyle())
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
