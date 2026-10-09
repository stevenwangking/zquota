// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "ZQuota",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "ZQuota", targets: ["ZQuota"])
    ],
    targets: [
        .target(
            name: "ZCodeTouchBarShim",
            path: "Shim"
        ),
        .executableTarget(
            name: "ZQuota",
            dependencies: ["ZCodeTouchBarShim"],
            path: "Sources"
        )
    ]
)
