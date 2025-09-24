// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "e2ecli",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "e2ecli", targets: ["e2ecli"]),
    ],
    dependencies: [
        .package(name: "Segment", path: "../../analytics-swift"),
    ],
    targets: [
        .target(
            name: "e2ecli",
            dependencies: [
                "Segment" 
            ]
        ),
        
    ]
)