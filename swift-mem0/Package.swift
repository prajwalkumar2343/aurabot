// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Mem0",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(
            name: "Mem0",
            targets: ["Mem0"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Mem0",
            dependencies: []
        ),
    ]
)
