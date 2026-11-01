// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IndependentConsumer",
    platforms: [.macOS(.v13)],
    dependencies: [.package(path: "../..")],
    targets: [
        .executableTarget(
            name: "ConsumerSmoke", dependencies: [.product(name: "LapisWebSearch", package: "LapisWebSearch")])
    ],
    swiftLanguageModes: [.v6]
)
