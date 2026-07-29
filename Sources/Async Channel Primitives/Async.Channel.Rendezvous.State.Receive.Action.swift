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

    extension Async.Channel.Rendezvous.State.Receive where Element: ~Copyable {
        enum Action: ~Copyable, Sendable {
            case wait(
                Async.Waiter.Queue.Drain<
                    Async.Waiter.Queue.Flagged<
                        Async.Channel<Element>.Rendezvous.State.Send.Signal,
                        Ownership.Slot<Element>
                    >
                >
            )
            case match(
                Async.Channel<Element>.Rendezvous.State.Match,
                Async.Waiter.Queue.Drain<
                    Async.Waiter.Queue.Flagged<
                        Async.Channel<Element>.Rendezvous.State.Send.Signal,
                        Ownership.Slot<Element>
                    >
                >
            )
            case stop(
                Async.Waiter.Entry<Signal, Ownership.Slot<Element>>,
                Signal,
                Async.Waiter.Queue.Drain<
                    Async.Waiter.Queue.Flagged<
                        Async.Channel<Element>.Rendezvous.State.Send.Signal,
                        Ownership.Slot<Element>
                    >
                >
            )
        }
    }

#endif  // !hasFeature(Embedded)
