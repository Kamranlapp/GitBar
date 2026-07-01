// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GitBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GitBar", targets: ["GitBar"])
    ],
    targets: [
        .executableTarget(
            name: "GitBar",
            path: "Sources/GitBar"
        )
    ]
)
