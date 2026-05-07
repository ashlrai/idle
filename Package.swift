// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Idle",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Idle", targets: ["Idle"])
    ],
    targets: [
        .executableTarget(
            name: "Idle",
            path: "Sources/Idle"
        )
    ]
)
