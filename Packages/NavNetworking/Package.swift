// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NavNetworking",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NavNetworking", targets: ["NavNetworking"]),
    ],
    targets: [
        .target(name: "NavNetworking"),
    ]
)
