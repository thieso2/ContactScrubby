// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ContactScrubby",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "contactscrub",
            targets: ["ContactScrubby"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-testing", from: "0.10.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "ContactScrubby",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "ContactScrubbyTests",
            dependencies: [
                "ContactScrubby",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Testing", package: "swift-testing")
            ]
        ),
    ]
)
