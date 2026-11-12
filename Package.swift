// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pilcrow",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Pilcrow",
            path: "Sources/Pilcrow",
            resources: [.process("Resources")]
        )
    ]
)
