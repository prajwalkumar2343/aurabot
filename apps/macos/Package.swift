// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AuraBot",
    platforms: [.macOS(.v14)],
    products: [
        .executable(
            name: "AuraBot",
            targets: ["AuraBot"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", exact: "1.10.0"),
        .package(url: "https://github.com/trycua/cua.git", revision: "cua-driver-v0.1.2"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "AuraBot",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "CuaDriverCore", package: "cua"),
                .product(name: "CuaDriverServer", package: "cua"),
                .product(name: "MCP", package: "swift-sdk"),
            ],
            resources: [
                .copy("Resources/BrowserExtension/chromium")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "AuraBotTests",
            dependencies: ["AuraBot"]
        )
    ]
)
