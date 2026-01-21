// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeviceOps",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "DeviceOpsCore", targets: ["DeviceOpsCore"]),
        .library(name: "DeviceOpsAPI", targets: ["DeviceOpsAPI"]),
        .executable(name: "devicectl", targets: ["devicectl"]),
        .executable(name: "deviceops-mock-server", targets: ["DeviceOpsMockServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.7.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.70.0")
    ],
    targets: [
        .target(
            name: "DeviceOpsAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession")
            ],
            path: "Shared/Sources/DeviceOpsAPI"
        ),
        .target(
            name: "DeviceOpsCore",
            dependencies: ["DeviceOpsAPI"],
            path: "Shared/Sources/DeviceOpsCore"
        ),
        .executableTarget(
            name: "devicectl",
            dependencies: [
                "DeviceOpsCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "CLI/Sources/devicectl"
        ),
        .executableTarget(
            name: "DeviceOpsMockServer",
            dependencies: [
                "DeviceOpsCore",
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIO", package: "swift-nio")
            ],
            path: "Server/Sources/DeviceOpsMockServer"
        ),
        .testTarget(
            name: "DeviceOpsCoreTests",
            dependencies: ["DeviceOpsCore"],
            path: "Shared/Tests/DeviceOpsCoreTests"
        )
    ]
)
