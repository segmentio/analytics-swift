// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "e2e-cli",
    platforms: [
        .macOS("10.15")
    ],
    dependencies: [
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "E2ECLI",
            dependencies: [
                .product(name: "Segment", package: "analytics-swift"),
            ]
        ),
    ]
)
