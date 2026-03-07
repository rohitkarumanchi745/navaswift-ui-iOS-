// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NavServices",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NavServices", targets: ["NavServices"]),
    ],
    dependencies: [
        .package(path: "../NavCore"),
        .package(path: "../NavNetworking"),
    ],
    targets: [
        .target(
            name: "NavServices",
            dependencies: ["NavCore", "NavNetworking"]
        ),
    ]
)
