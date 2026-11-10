// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Vitals",
    platforms: [.macOS(.v14)],
    targets: [
        // C wrappers around the SMC, the HID sensor service and IOReport.
        .target(
            name: "CVitals",
            linkerSettings: [
                .linkedFramework("CoreFoundation"),
                .linkedFramework("IOKit"),
                .linkedLibrary("IOReport"),
            ]
        ),
        // Reads the hardware. No UI.
        .target(
            name: "VitalsCore",
            dependencies: ["CVitals"],
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        // The menu bar app. The target is named Vitals so the binary is too.
        .executableTarget(
            name: "Vitals",
            dependencies: ["VitalsCore"],
            path: "Sources/VitalsApp"
        ),
        .executableTarget(
            name: "vitals-probe",
            dependencies: ["VitalsCore"]
        ),
        .testTarget(
            name: "VitalsCoreTests",
            dependencies: ["VitalsCore"]
        ),
    ]
)
