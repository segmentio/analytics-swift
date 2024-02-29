// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Segment",
    platforms: [
        .macOS("10.15"),
        .iOS("13.0"),
        .tvOS("11.0"),
        .watchOS("7.1"),
        .visionOS("1.0")
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Segment",
            targets: ["Segment"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/segmentio/sovran-swift.git", from: "1.1.1"),
        .package(url: "https://github.com/segmentio/jsonsafeencoder-swift.git", from: "1.0.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Segment",
            dependencies: [
                .product(name: "Sovran", package: "sovran-swift"),
                .product(name: "JSONSafeEncoder", package: "jsonsafeencoder-swift")
            ],
            exclude: ["PrivacyInfo.xcprivacy"]),
        .testTarget(
            name: "Segment-Tests",
            dependencies: ["Segment"]),
    ]
)
