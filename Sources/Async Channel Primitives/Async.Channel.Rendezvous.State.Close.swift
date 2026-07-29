// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-async open source project
//
// Copyright (c) 2025-2026 Coen ten Thije Boonkkamp and the swift-async project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// Async channels require task suspension which is not available on embedded Swift.
#if !hasFeature(Embedded)

    import Async_Waiter_Primitives
    import Ownership_Primitives
    import Queue_Primitive

    extension Async.Channel.Rendezvous.State where Element: ~Copyable {
        /// Pending operations detached by close.
        struct Close: ~Copyable, Sendable {
            var senders:
                Async.Waiter.Queue.Unbounded<
                    Send.Signal,
                    Ownership.Slot<Element>
                >
            var receivers:
                Async.Waiter.Queue.Unbounded<
                    Receive.Signal,
                    Ownership.Slot<Element>
                >
            init() {
                self.senders = .init()
                self.receivers = .init()
            }
        }
    }

#endif  // !hasFeature(Embedded)
