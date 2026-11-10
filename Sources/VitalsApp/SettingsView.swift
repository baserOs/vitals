import AppKit
import ServiceManagement
import SwiftUI
import VitalsCore

struct SettingsView: View {
    @EnvironmentObject private var sampler: Sampler
    @AppStorage(SettingsKey.refreshInterval) private var interval = SettingsDefault.refreshInterval
    @AppStorage(SettingsKey.menuBarFields) private var fieldsText = SettingsDefault.menuBarFields
    @AppStorage(SettingsKey.temperatureUnit) private var unit: TemperatureUnit = .celsius
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var diagnosticsStatus: String?

    var body: some View {
        Form {
            Section("Show in the menu bar") {
                ForEach(MenuBarField.allCases) { field in
                    Toggle(field.title, isOn: binding(for: field))
                }
            }
            Section("Display") {
                Picker("Refresh every", selection: $interval) {
                    Text("1 second").tag(1.0)
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                }
                Picker("Temperature unit", selection: $unit) {
                    Text("Celsius").tag(TemperatureUnit.celsius)
                    Text("Fahrenheit").tag(TemperatureUnit.fahrenheit)
                }
            }
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                if let loginError = loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(Color.red)
                }
                HStack {
                    Button("Copy diagnostics") {
                        copyDiagnostics()
                    }
                    if let diagnosticsStatus = diagnosticsStatus {
                        Text(diagnosticsStatus)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 440)
        .onChange(of: interval) {
            sampler.interval = interval
        }
        .onChange(of: launchAtLogin) {
            applyLaunchAtLogin()
        }
    }

    private func binding(for field: MenuBarField) -> Binding<Bool> {
        Binding(
            get: { MenuBarField.parse(fieldsText).contains(field) },
            set: { isOn in
                var fields = MenuBarField.parse(fieldsText)
                fields.removeAll(where: { $0 == field })
                if isOn { fields.append(field) }
                fieldsText = MenuBarField.serialize(fields)
            }
        )
    }

    private func applyLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if launchAtLogin, service.status != .enabled {
                try service.register()
            } else if !launchAtLogin, service.status == .enabled {
                try service.unregister()
            }
            loginError = nil
        } catch {
            loginError = "Could not change this setting: \(error.localizedDescription)"
            launchAtLogin = service.status == .enabled
        }
    }

    private func copyDiagnostics() {
        diagnosticsStatus = "Collecting, about two seconds…"
        sampler.runDiagnostics { report in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(report, forType: .string)
            diagnosticsStatus = "Copied. Paste it into the chat."
        }
    }
}
