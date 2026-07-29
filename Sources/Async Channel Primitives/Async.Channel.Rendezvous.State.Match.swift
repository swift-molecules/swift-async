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

    extension Async.Channel.Rendezvous.State where Element: ~Copyable {
        /// One admitted sender/receiver pair.
        struct Match: ~Copyable, Sendable {
            var sender:
                Async.Waiter.Entry<
                    Send.Signal,
                    Ownership.Slot<Element>
                >
            var receiver:
                Async.Waiter.Entry<
                    Receive.Signal,
                    Ownership.Slot<Element>
                >
            init(
                sender: consuming Async.Waiter.Entry<
                    Send.Signal,
                    Ownership.Slot<Element>
                >,
                receiver: consuming Async.Waiter.Entry<
                    Receive.Signal,
                    Ownership.Slot<Element>
                >
            ) {
                self.sender = sender
                self.receiver = receiver
            }
        }
    }

#endif  // !hasFeature(Embedded)
