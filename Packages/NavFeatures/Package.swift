// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NavFeatures",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NavFeatures", targets: ["NavFeatures"]),
    ],
    dependencies: [
        .package(path: "../NavCore"),
        .package(path: "../NavNetworking"),
        .package(path: "../NavServices"),
    ],
    targets: [
        .target(
            name: "NavFeatures",
            dependencies: ["NavCore", "NavNetworking", "NavServices"]
        ),
    ]
)
