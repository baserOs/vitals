# Vitalis

A menu bar app for Apple Silicon MacBooks that shows what the machine is
doing: CPU per core, GPU, memory, every temperature sensor, fan speeds,
power draw, battery and the busiest processes.

It only reads. It does not control fans or change any system setting, and
it needs no administrator password.

## Requirements

- Apple Silicon Mac, macOS 14 or later.
- The menu bar popover is drawn as Liquid Glass on macOS 26 and later.
  Earlier versions get the same layout on a translucent material.

## Get the app

Every push to `main` is built by GitHub Actions on a Mac. The finished app
is attached to the release named `latest` as `Vitalis.zip`.

1. Download `Vitalis.zip` from the repository's Releases page and unzip it.
2. Move `Vitalis.app` to the Applications folder.
3. Open it. The first time, macOS blocks it because it is not signed by a
   registered developer. Go to System Settings, Privacy & Security, scroll
   down and choose "Open Anyway".

The app has no Dock icon. Look for the temperature and watts in the menu
bar and click them.

The app was called Vitals before. If `Vitals.app` is still installed, quit
it and move it to the Trash; your settings carry over to Vitalis.

## Build it yourself

Needs Xcode or the Xcode Command Line Tools.

```bash
./scripts/make-app.sh
```

```bash
open Vitalis.app
```

Run the tests:

```bash
swift test
```

Print everything the app can read on this Mac:

```bash
swift run vitalis-probe
```

## Layout

| Path | What it holds |
|---|---|
| `Sources/CVitalis` | C wrappers for the SMC, the HID sensor service and IOReport |
| `Sources/VitalisCore` | One source per kind of reading, the sampler, formatting |
| `Sources/VitalisApp` | The SwiftUI menu bar item, popover, dashboard and settings |
| `Sources/vitalis-probe` | Command-line dump of every reading |
| `Tests/VitalisCoreTests` | Tests for the logic that does not need hardware |
| `Assets` | The app icon: the drawing (`AppIcon.svg`) and its 1024 px render |

## Limits

- The process list shows only your own apps. macOS does not give usage
  figures for system processes to an app without administrator rights.
- Sensor names differ between chip generations. Sensors the app does not
  know by name are listed under their raw key. "Copy diagnostics" in
  Settings produces a report that can be used to name them.
