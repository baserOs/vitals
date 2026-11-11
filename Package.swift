// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Vitalis",
    platforms: [.macOS(.v14)],
    targets: [
        // C wrappers around the SMC, the HID sensor service and IOReport.
        .target(
            name: "CVitalis",
            linkerSettings: [
                .linkedFramework("CoreFoundation"),
                .linkedFramework("IOKit"),
                .linkedLibrary("IOReport"),
            ]
        ),
        // Reads the hardware. No UI.
        .target(
            name: "VitalisCore",
            dependencies: ["CVitalis"],
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        // The menu bar app. The target is named Vitalis so the binary is too.
        .executableTarget(
            name: "Vitalis",
            dependencies: ["VitalisCore"],
            path: "Sources/VitalisApp"
        ),
        .executableTarget(
            name: "vitalis-probe",
            dependencies: ["VitalisCore"]
        ),
        .testTarget(
            name: "VitalisCoreTests",
            dependencies: ["VitalisCore"]
        ),
    ]
)
