// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Wakebar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "WakebarCore", targets: ["WakebarCore"]),
        .executable(name: "Wakebar", targets: ["WakebarApp"])
    ],
    targets: [
        .target(name: "WakebarCore"),
        .executableTarget(name: "WakebarApp", dependencies: ["WakebarCore"]),
        .testTarget(name: "WakebarTests", dependencies: ["WakebarCore"])
    ]
)
