// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let swiftSettings: Array<SwiftSetting> = [
    .enableUpcomingFeature("ConciseMagicFile"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("BareSlashRegexLiterals"),
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableExperimentalFeature("StrictConcurrency"),
//    .enableExperimentalFeature("AccessLevelOnImport"),
//    .enableExperimentalFeature("VariadicGenerics"),
]

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
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.59.0"),
        .package(url: "https://github.com/vapor/vapor", from: "4.84.0"),
        .package(url: "https://github.com/vapor/leaf-kit", from: "1.10.0"),
        .package(url: "https://github.com/vapor/leaf", from: "4.2.0"),
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
            ],
            resources: [
                .copy("DefaultDocsView"),
            ],
            swiftSettings: swiftSettings),
        .testTarget(
            name: "RouteDocsTests",
            dependencies: ["RouteDocs"],
            swiftSettings: swiftSettings),
    ]
)
