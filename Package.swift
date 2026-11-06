// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Wagebeat",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Wagebeat",
            path: "Sources/Wagebeat"
        )
    ]
)
