// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AuraBot",
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "AuraBot",
            targets: ["AuraBot"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(path: "../swift-mem0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
    ],
    targets: [
        .executableTarget(
            name: "AuraBot",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Mem0", package: "swift-mem0"),
                .product(name: "Alamofire", package: "Alamofire"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
