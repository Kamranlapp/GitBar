// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ProjectBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ProjectBar", targets: ["ProjectBar"])
    ],
    targets: [
        .executableTarget(
            name: "ProjectBar",
            path: "Sources/ProjectBar"
        )
    ]
)
