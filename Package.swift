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
            name: "Async Primitive",
            targets: ["Async Primitive"]
        ),
        .library(
            name: "Async Callback",
            targets: ["Async Callback"]
        ),
        .library(
            name: "Async Cancellation",
            targets: ["Async Cancellation"]
        ),
        .library(
            name: "Async Continuation",
            targets: ["Async Continuation"]
        ),
        .library(
            name: "Async Demand",
            targets: ["Async Demand"]
        ),
        .library(
            name: "Async Lifecycle",
            targets: ["Async Lifecycle"]
        ),
        .library(
            name: "Async Precedence",
            targets: ["Async Precedence"]
        ),

        .library(
            name: "Async Mutex",
            targets: ["Async Mutex"]
        ),

        .library(
            name: "Async Bridge",
            targets: ["Async Bridge"]
        ),
        .library(
            name: "Async Promise",
            targets: ["Async Promise"]
        ),
        .library(
            name: "Async Publication",
            targets: ["Async Publication"]
        ),
        .library(
            name: "Async Barrier",
            targets: ["Async Barrier"]
        ),
        .library(
            name: "Async Completion",
            targets: ["Async Completion"]
        ),

        .library(
            name: "Async Channel",
            targets: ["Async Channel"]
        ),
        .library(
            name: "Async Broadcast",
            targets: ["Async Broadcast"]
        ),
        .library(
            name: "Async Waiter",
            targets: ["Async Waiter"]
        ),
        .library(
            name: "Async Semaphore",
            targets: ["Async Semaphore"]
        ),

        .library(
            name: "Async",
            targets: ["Async"]
        ),
        .library(
            name: "Async Test Support",
            targets: ["Async Test Support"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-molecules/swift-buffer.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-buffer-ring.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-buffer-linear.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-storage.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-memory-allocation.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-memory-heap.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-dictionary.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-dictionary-ordered.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-hash.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-hash-table.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-index.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-queue.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-column.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-deque.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-tagged.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-ownership.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-either.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-pair.git",
            branch: "main"
        ),
    ],
    targets: [

        .target(
            name: "Async Primitive",
            dependencies: []
        ),
        .target(
            name: "Async Callback",
            dependencies: ["Async Primitive"]
        ),
        .target(
            name: "Async Cancellation",
            dependencies: [
                "Async Primitive",
                "Async Mutex",
            ]
        ),
        .target(
            name: "Async Continuation",
            dependencies: ["Async Primitive"]
        ),
        .target(
            name: "Async Demand",
            dependencies: ["Async Primitive"]
        ),
        .target(
            name: "Async Lifecycle",
            dependencies: ["Async Primitive"]
        ),
        .target(
            name: "Async Precedence",
            dependencies: ["Async Primitive"]
        ),

        .target(
            name: "Async Mutex",
            dependencies: [
                "Async Primitive"
            ]
        ),

        .target(
            name: "Async Bridge",
            dependencies: [
                "Async Primitive",
                "Async Mutex",
                .product(name: "Buffer Primitive", package: "swift-buffer"),
                .product(name: "Buffer Ring Primitive", package: "swift-buffer-ring"),
                .product(name: "Column", package: "swift-column"),
                .product(name: "Deque", package: "swift-deque"),
                .product(
                    name: "Memory Allocator Primitive",
                    package: "swift-memory-allocation"
                ),
                .product(name: "Memory Heap", package: "swift-memory-heap"),
                .product(name: "Queue", package: "swift-queue"),
                .product(
                    name: "Storage Contiguous",
                    package: "swift-storage"
                ),
            ]
        ),
        .target(
            name: "Async Promise",
            dependencies: [
                "Async Primitive",
                "Async Continuation",
                "Async Mutex",
            ]
        ),
        .target(
            name: "Async Publication",
            dependencies: [
                "Async Primitive",
                "Async Mutex",
            ]
        ),
        .target(
            name: "Async Barrier",
            dependencies: [
                "Async Primitive",
                "Async Lifecycle",
                "Async Mutex",
                "Async Waiter",
            ]
        ),
        .target(
            name: "Async Completion",
            dependencies: [
                "Async Primitive",
                "Async Mutex",
            ]
        ),

        .target(
            name: "Async Channel",
            dependencies: [
                "Async Primitive",
                "Async Continuation",
                "Async Mutex",
                "Async Waiter",
                .product(name: "Buffer Primitive", package: "swift-buffer"),
                .product(name: "Buffer Ring Primitive", package: "swift-buffer-ring"),
                .product(name: "Column", package: "swift-column"),
                .product(name: "Deque", package: "swift-deque"),
                .product(
                    name: "Memory Allocator Primitive",
                    package: "swift-memory-allocation"
                ),
                .product(name: "Memory Heap", package: "swift-memory-heap"),
                .product(name: "Ownership", package: "swift-ownership"),
                .product(name: "Pair", package: "swift-pair"),
                .product(name: "Queue", package: "swift-queue"),
                .product(name: "Index", package: "swift-index"),
                .product(
                    name: "Storage Contiguous",
                    package: "swift-storage"
                ),
            ]
        ),
        .target(
            name: "Async Broadcast",
            dependencies: [
                "Async Primitive",
                "Async Mutex",
                "Async Publication",
                .product(
                    name: "Buffer Linear Primitive",
                    package: "swift-buffer-linear"
                ),
                .product(name: "Buffer Primitive", package: "swift-buffer"),
                .product(name: "Buffer Ring Primitive", package: "swift-buffer-ring"),
                .product(name: "Column", package: "swift-column"),
                .product(name: "Deque", package: "swift-deque"),
                .product(
                    name: "Dictionary Ordered",
                    package: "swift-dictionary-ordered"
                ),
                .product(name: "Dictionary", package: "swift-dictionary"),
                .product(name: "Hash Indexed Primitive", package: "swift-hash-table"),
                .product(name: "Hash", package: "swift-hash"),
                .product(name: "Index", package: "swift-index"),
                .product(
                    name: "Memory Allocator Primitive",
                    package: "swift-memory-allocation"
                ),
                .product(name: "Memory Heap", package: "swift-memory-heap"),
                .product(name: "Queue", package: "swift-queue"),
                .product(
                    name: "Storage Contiguous",
                    package: "swift-storage"
                ),
            ]
        ),
        .target(
            name: "Async Waiter",
            dependencies: [
                "Async Primitive",
                "Async Continuation",
                .product(name: "Buffer Primitive", package: "swift-buffer"),
                .product(
                    name: "Buffer Ring Bounded Primitive",
                    package: "swift-buffer-ring"
                ),
                .product(name: "Buffer Ring Primitive", package: "swift-buffer-ring"),
                .product(name: "Column", package: "swift-column"),
                .product(
                    name: "Memory Allocator Primitive",
                    package: "swift-memory-allocation"
                ),
                .product(name: "Memory Heap", package: "swift-memory-heap"),
                .product(name: "Queue", package: "swift-queue"),
                .product(
                    name: "Storage Contiguous",
                    package: "swift-storage"
                ),
                .product(name: "Tagged", package: "swift-tagged"),
            ]
        ),

        .target(
            name: "Async Semaphore",
            dependencies: [
                "Async Primitive",
                "Async Continuation",
                "Async Lifecycle",
                "Async Precedence",
                "Async Mutex",
                "Async Promise",
                "Async Waiter",
                .product(name: "Either", package: "swift-either"),
                .product(name: "Queue Primitive", package: "swift-queue"),
                .product(name: "Queue", package: "swift-queue"),
            ]
        ),

        .target(
            name: "Async",
            dependencies: [
                "Async Primitive",
                "Async Callback",
                "Async Cancellation",
                "Async Continuation",
                "Async Demand",
                "Async Lifecycle",
                "Async Precedence",
                "Async Mutex",
                "Async Bridge",
                "Async Promise",
                "Async Publication",
                "Async Barrier",
                "Async Completion",
                "Async Channel",
                "Async Broadcast",
                "Async Waiter",
                "Async Semaphore",
            ]
        ),

        .testTarget(
            name: "Async Tests",
            dependencies: [
                "Async",
                "Async Test Support",
            ]
        ),

        .target(
            name: "Async Test Support",
            dependencies: [
                "Async",
                .product(
                    name: "Buffer Test Support",
                    package: "swift-buffer"
                ),
                .product(name: "Queue Test Support", package: "swift-queue"),
                .product(
                    name: "Tagged Test Support",
                    package: "swift-tagged"
                ),
            ],
            path: "Tests/Support"
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
