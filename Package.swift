// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DeCleanMac",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "DeCleanMac",
            path: "Sources/DeCleanMac"
        )
    ]
)
