// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Wakebar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "WakebarCore", targets: ["WakebarCore"]),
        .executable(name: "Wakebar", targets: ["WakebarApp"]),
        .executable(name: "WakebarVerification", targets: ["WakebarVerification"])
    ],
    targets: [
        .target(name: "WakebarCore"),
        .executableTarget(name: "WakebarApp", dependencies: ["WakebarCore"]),
        .executableTarget(
            name: "WakebarVerification",
            dependencies: ["WakebarCore"],
            path: "Verification"
        ),
        .testTarget(name: "WakebarTests", dependencies: ["WakebarCore"]),
        .testTarget(
            name: "WakebarAppTests",
            dependencies: ["WakebarApp", "WakebarCore"]
        )
    ]
)
