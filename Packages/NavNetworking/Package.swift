// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NavNetworking",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NavNetworking", targets: ["NavNetworking"]),
    ],
    dependencies: [
        .package(path: "../NavCore"),
    ],
    targets: [
        .target(
            name: "NavNetworking",
            dependencies: ["NavCore"]
        ),
    ]
)
