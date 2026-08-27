// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-async",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(
            name: "Async",
            targets: ["Async"]
        ),
        .library(
            name: "Async Standard Library Integration",
            targets: ["Async Standard Library Integration"]
        ),
        .library(
            name: "Async Apple Foundation Integration",
            targets: ["Async Apple Foundation Integration"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Async",
            dependencies: []
        ),
        .target(
            name: "Async Standard Library Integration",
            dependencies: ["Async"]
        ),
        .target(
            name: "Async Apple Foundation Integration",
            dependencies: [
                "Async",
                "Async Standard Library Integration",
            ]
        ),
        .testTarget(
            name: "Async Tests",
            dependencies: ["Async"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]

    let package: [SwiftSetting] = [
        .enableExperimentalFeature("RawLayout")
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
