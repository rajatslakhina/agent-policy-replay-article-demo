// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PolicyReplay",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PolicyReplay", targets: ["PolicyReplay"]),
    ],
    targets: [
        .target(name: "PolicyReplay"),
        .testTarget(name: "PolicyReplayTests", dependencies: ["PolicyReplay"]),
    ]
)
