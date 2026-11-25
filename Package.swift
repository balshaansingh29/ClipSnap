// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClipSnap",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClipSnap",
            path: "Sources/ClipSnap"
        )
    ]
)
