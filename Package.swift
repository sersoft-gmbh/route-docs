// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "route-docs",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "RouteDocs",
            targets: ["RouteDocs"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.33.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.50.0"),
        .package(url: "https://github.com/vapor/leaf-kit.git", from: "1.3.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.0.0"),
        .package(url: "https://github.com/ffried/FFFoundation.git", from: "9.2.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "RouteDocs",
            dependencies: [
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "LeafKit", package: "leaf-kit"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "FFFoundation", package: "FFFoundation"),
            ],
            resources: [
                .copy("DefaultDocsView"),
            ]),
        .testTarget(
            name: "RouteDocsTests",
            dependencies: ["RouteDocs"]),
    ]
)
