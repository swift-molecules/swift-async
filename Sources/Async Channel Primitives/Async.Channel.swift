// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-async open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-async project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// Async channels require task suspension which is not available on embedded Swift.
#if !hasFeature(Embedded)

    extension Async {
        /// Implementation namespace for the untyped bounded channel machinery.
        ///
        /// Channels provide structured communication between concurrent tasks.
        /// Available channel types:
        /// - `Unbounded`: Unlimited buffer, sync send, async receive
        /// - `Bounded`: Capacity-limited buffer with backpressure
        public struct _Channel<Element: ~Copyable> {}
    }

#endif  // !hasFeature(Embedded)
