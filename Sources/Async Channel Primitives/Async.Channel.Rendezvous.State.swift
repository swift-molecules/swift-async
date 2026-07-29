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

    extension Async.Channel.Rendezvous where Element: ~Copyable {
        /// Pure state for rendezvous admission.
        struct State: ~Copyable, Sendable {
            var status: Status
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
                self.status = .open
                self.senders = .init()
                self.receivers = .init()
            }
        }
    }

    extension Async.Channel.Rendezvous.State where Element: ~Copyable {
        var isClosed: Bool {
            status == .closed
        }
    }

#endif  // !hasFeature(Embedded)
