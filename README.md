# Vitalis

A menu bar app for Apple Silicon MacBooks that shows what the machine is
doing: CPU per core, GPU, memory, temperatures, fan speeds, power draw,
battery, network speed and the busiest apps.

It only reads. It does not control fans or change any system setting, it
sends nothing over the network, and it needs no administrator password.

## What it shows

- **Menu bar:** the readings you pick, as text.
- **Popup:** one card per vital, with the five apps using the most memory.
- **Dashboard:** ten minutes of history for CPU, memory, temperature,
  power, fan speed, download and upload, and every reading in full.
- **Apps, not loose processes:** a process is counted under the app it
  works for, so a browser's tabs add up under the browser. Click an app to
  see its processes.
- **Temperatures:** one reading each for CPU, GPU, battery, SSD and palm
  rest. The dashboard keeps the full sensor list folded underneath.

While neither the popup nor the dashboard is open, the app draws nothing
and skips the app lists, which are its most expensive readings.

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

Draw the dashboard and the popup with sample data, as PNG files:

```bash
VITALIS_SCREENSHOTS=/tmp/vitalis-screens swift test --filter ScreenshotTests
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
| `Tests/VitalisAppTests` | Draws the screens with sample data |
| `Assets` | The app icon: the drawing (`AppIcon.svg`) and its 1024 px render |

## Limits

- The process list shows only your own apps. macOS does not give usage
  figures for system processes to an app without administrator rights.
- The GPU table splits the GPU's total use between apps in proportion to
  the GPU time the graphics driver reports for each. It is empty while
  nothing is drawing.
- Network speed is what is flowing right now, not what the connection
  could carry. It counts Wi-Fi and Ethernet.
- Sensor names differ between chip generations. Sensors the app does not
  know by name are listed under their raw key. "Copy diagnostics" in
  Settings produces a report that can be used to name them.
