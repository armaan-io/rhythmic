// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RhythmTiming",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "TimingCore", targets: ["TimingCore"])],
    targets: [
        .target(name: "TimingCore"),
        .testTarget(name: "TimingCoreTests", dependencies: ["TimingCore"])
    ]
)
