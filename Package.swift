// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ContactsCLI",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(
            name: "ContactsCLI",
            targets: ["ContactsCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "ContactsCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
    ]
)
