// swift-tools-version:5.9
// Runs the app's platform-independent logic tests with `swift test` (macOS or Linux).
// The iOS app itself is built from fluffy-sniffle.xcodeproj.
import PackageDescription

let package = Package(
    name: "RenewalCore",
    targets: [
        .target(name: "RenewalCore", path: "fluffy-sniffle/Core"),
        .testTarget(name: "RenewalCoreTests", dependencies: ["RenewalCore"], path: "Tests/RenewalCoreTests"),
    ]
)
