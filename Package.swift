// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftMCPServer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SwiftMCPServer",
            targets: ["SwiftMCPServer"]
        )
    ],
    dependencies: [
        // MCP SDK
        .package(
            url: "https://github.com/modelcontextprotocol/swift-sdk.git",
            from: "0.10.0"
        ),
        // SwiftNIO for cross-platform HTTP server
        .package(
            url: "https://github.com/apple/swift-nio.git",
            from: "2.65.0"
        ),
        .package(
            url: "https://github.com/apple/swift-nio-ssl.git",
            from: "2.26.0"
        ),
        // Cryptography (cross-platform: macOS + Linux)
        .package(
            url: "https://github.com/apple/swift-crypto.git",
            from: "3.0.0"
        ),
        // DocC plugin for documentation generation
        .package(
            url: "https://github.com/apple/swift-docc-plugin",
            from: "1.3.0"
        )
    ],
    targets: [
        // System library for SQLite (available on macOS and Linux)
        .systemLibrary(
            name: "CSQLite",
            pkgConfig: "sqlite3",
            providers: [
                .brew(["sqlite3"]),
                .apt(["libsqlite3-dev"])
            ]
        ),
        .target(
            name: "SwiftMCPServer",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "Crypto", package: "swift-crypto"),
                "CSQLite"
            ]
        ),
        .testTarget(
            name: "SwiftMCPServerTests",
            dependencies: ["SwiftMCPServer"]
        )
    ]
)
