# Vitals — design

Date: 2026-11-10

## Purpose

A personal macOS menu bar app that replaces btop, Activity Monitor and
Macs Fan Control for one job: seeing what the machine is doing. It shows
CPU, GPU, memory, temperatures, fan speeds, power draw and battery in one
place.

It is read-only. It does not control fans or change any system setting.

## Target

- Apple Silicon MacBook Pro, macOS 14 or later.
- Single user, built from source on that Mac. No App Store, no paid
  developer account, no notarization.
- Runs unprivileged. No root helper, no admin password, no `sudo`.

## Success criteria

- One glance at the menu bar answers "how hot, how busy, how much power".
- One click shows everything btop would, without opening a terminal.
- The app itself stays light: under 1% CPU on average and under 60 MB of
  memory at the default 2-second refresh.

## Build

Swift Package, built with `swift build -c release`. A script,
`scripts/make-app.sh`, assembles `Vitals.app` (Info.plist with
`LSUIElement` so there is no Dock icon) and ad-hoc signs it. No Xcode
project. Xcode Command Line Tools are enough.

## Structure

Three targets in one package:

| Target | Kind | Responsibility |
|---|---|---|
| `VitalsCore` | library | Reads the hardware. No UI. Each source is one file with one job. |
| `VitalsApp` | executable | SwiftUI menu bar item, popover, dashboard window, settings. |
| `vitals-probe` | executable | Command-line dump of everything `VitalsCore` can read on this Mac. |

### VitalsCore sources

Each source exposes `read() -> Reading?` and returns `nil` or an empty
list when the hardware does not answer, so one failing source never
blocks the others.

| Source | Data | Mechanism |
|---|---|---|
| `CPUSource` | Total and per-core usage, split into performance and efficiency cores, load average | `host_processor_info`, `sysctl hw.perflevel*` |
| `MemorySource` | Used, wired, compressed, cached, free, swap, memory pressure level | `host_statistics64`, `sysctl vm.swapusage`, `kern.memorystatus_vm_pressure_level` |
| `GPUSource` | GPU utilisation | IORegistry `IOAccelerator` `PerformanceStatistics` |
| `TemperatureSource` | Every temperature sensor, with a readable name and a group (CPU, GPU, battery, SSD, other) | SMC keys of type `flt`, plus the HID sensor service as a second source |
| `FanSource` | Per fan: current RPM, minimum, maximum | SMC `FNum`, `F<n>Ac`, `F<n>Mn`, `F<n>Mx` — read only |
| `PowerSource` | Total system watts, adapter input watts, CPU and GPU watts | SMC `PSTR`, `PDTR`; IOReport "Energy Model" channels sampled as deltas |
| `BatterySource` | Charge %, charging state, battery watts in or out, cycle count, health, temperature | IORegistry `AppleSmartBattery` |
| `ProcessSource` | Top processes by CPU and by memory | `proc_listpids`, `proc_pid_rusage` |

`SMC.swift` is a small shared client for the `AppleSMC` IOKit service:
open, read key info, read value, decode `flt`, `ui8`, `ui16`, `fpe2`. It
has no write path.

`Sampler` owns the sources, polls them on a background queue at the
chosen interval, and publishes one immutable `Snapshot`. It keeps a ring
buffer of recent snapshots (10 minutes) for the graphs. Process sampling
runs only while the popover or dashboard is open.

### VitalsApp

- **Menu bar item.** Text readout built from user-chosen fields: CPU %,
  hottest temperature, fan RPM, watts, memory %. Default: temperature
  and watts.
- **Popover.** Opens on click. Sections: CPU (bar per core, P and E
  grouped), GPU, memory (stacked bar plus pressure), temperatures
  (grouped, hottest first), fans (RPM against min and max), power
  (system, CPU, GPU, adapter), battery, top five processes.
- **Dashboard window.** Same sections with history graphs (Swift Charts)
  and the full sensor and process lists.
- **Settings.** Refresh interval (1, 2, 5 s), menu bar fields,
  Celsius or Fahrenheit, launch at login (`SMAppService.mainApp`).

Views read the `Snapshot` and history only. They never call a source.

### vitals-probe

Prints every SMC key that decodes as a temperature, fan or power value,
the HID sensors, the IOReport energy channels, and one sample from each
source. Sensor keys differ between M-series generations, so this output
is how the sensor name table gets filled in for the actual machine.

## Error handling

- A source that fails returns nothing; its section shows "not available"
  and the rest of the app works.
- Unknown temperature keys appear under "Other" with the raw key as the
  name instead of being dropped.
- Implausible values (temperature below 0 or above 130 °C, negative
  watts) are discarded.
- If the SMC cannot be opened at all, temperatures, fans and SMC power
  are marked unavailable, and CPU, memory, GPU, battery and IOReport
  power still work.

## Testing

- Unit tests in `VitalsCore` for the pure parts: SMC value decoding, CPU
  tick deltas to percentages, IOReport energy deltas to watts, ring
  buffer, sensor naming and grouping, plausibility filter. These run
  with `swift test` on any Mac.
- Hardware reads cannot be unit tested. They are verified by running
  `vitals-probe` on the target Mac and comparing against `powermetrics`
  and Activity Monitor.
- The code is written in a Linux container that cannot compile it. The
  first build on the Mac is expected to surface compile errors, which
  are fixed from the pasted output.

## Order of work

1. Package skeleton, `SMC.swift`, all sources, `vitals-probe`. Run the
   probe on the Mac and paste the output.
2. Sensor name table from the probe output; `Sampler` and `Snapshot`.
3. Menu bar item and popover.
4. Dashboard window with graphs; settings; launch at login.

## Out of scope

- Fan control of any kind.
- Network and disk throughput, per-process power, notifications and
  alerts, widgets, Intel Macs.
