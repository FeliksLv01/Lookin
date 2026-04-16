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
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.12.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0")
    ],
    targets: [
        .target(
            name: "LookinMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio")
            ],
            path: "Sources/LookinMCP"
        )
    ]
)
