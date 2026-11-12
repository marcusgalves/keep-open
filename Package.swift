// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeepOpen",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "KeepOpen",
            path: "Sources/KeepOpen"
        )
    ],
    swiftLanguageModes: [.v5]
)
