// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "LookinMCP",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "LookinMCP", targets: ["LookinMCP"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0")
    ],
    targets: [
        .target(
            name: "LookinMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/LookinMCP"
        )
    ]
)
