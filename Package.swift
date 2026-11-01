// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LapisWebSearch",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "LapisWebSearch", targets: ["LapisWebSearch"]),
        .executable(name: "LapisWebSearchCLI", targets: ["LapisWebSearchCLI"]),
    ],
    targets: [
        .target(name: "LapisWebSearch"),
        .executableTarget(name: "LapisWebSearchCLI", dependencies: ["LapisWebSearch"]),
        .testTarget(name: "LapisWebSearchTests", dependencies: ["LapisWebSearch"], resources: [.process("Fixtures")]),
    ],
    swiftLanguageModes: [.v6]
)
