# Vitals

A menu bar app for Apple Silicon MacBooks that shows what the machine is
doing: CPU per core, GPU, memory, every temperature sensor, fan speeds,
power draw, battery and the busiest processes.

It only reads. It does not control fans or change any system setting, and
it needs no administrator password.

## Requirements

- Apple Silicon Mac, macOS 14 or later.

## Get the app

Every push to `main` is built by GitHub Actions on a Mac. The finished app
is attached to the release named `latest` as `Vitals.zip`.

1. Download `Vitals.zip` from the repository's Releases page and unzip it.
2. Move `Vitals.app` to the Applications folder.
3. Open it. The first time, macOS blocks it because it is not signed by a
   registered developer. Go to System Settings, Privacy & Security, scroll
   down and choose "Open Anyway".

The app has no Dock icon. Look for the temperature and watts in the menu
bar and click them.

## Build it yourself

Needs Xcode or the Xcode Command Line Tools.

```bash
./scripts/make-app.sh
```

```bash
open Vitals.app
```

Run the tests:

```bash
swift test
```

Print everything the app can read on this Mac:

```bash
swift run vitals-probe
```

## Layout

| Path | What it holds |
|---|---|
| `Sources/CVitals` | C wrappers for the SMC, the HID sensor service and IOReport |
| `Sources/VitalsCore` | One source per kind of reading, the sampler, formatting |
| `Sources/VitalsApp` | The SwiftUI menu bar item, popover, dashboard and settings |
| `Sources/vitals-probe` | Command-line dump of every reading |
| `Tests/VitalsCoreTests` | Tests for the logic that does not need hardware |

## Limits

- The process list shows only your own apps. macOS does not give usage
  figures for system processes to an app without administrator rights.
- Sensor names differ between chip generations. Sensors the app does not
  know by name are listed under their raw key. "Copy diagnostics" in
  Settings produces a report that can be used to name them.
