// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ContactScrubby",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(
            name: "contactscrub",
            targets: ["ContactScrubby"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.2.0")
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
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
    ]
)
