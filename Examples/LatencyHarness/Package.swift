// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LatencyHarness", platforms: [.macOS(.v13)],
    dependencies: [.package(path: "../..")],
    targets: [
        .executableTarget(
            name: "LatencyHarness", dependencies: [.product(name: "LapisWebSearch", package: "LapisWebSearch")])
    ],
    swiftLanguageModes: [.v6])
