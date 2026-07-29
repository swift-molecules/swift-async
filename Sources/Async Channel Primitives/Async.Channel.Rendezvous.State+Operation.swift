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
    import Queue_Primitives

    extension Async.Channel.Rendezvous.State where Element: ~Copyable {
        mutating func send(
            _ entry: consuming Async.Waiter.Entry<
                Send.Signal,
                Ownership.Slot<Element>
            >
        ) -> Send.Action {
            var cancelled:
                Async.Waiter.Queue.Drain<
                    Async.Waiter.Queue.Flagged<
                        Receive.Signal,
                        Ownership.Slot<Element>
                    >
                > = .init()

            guard !isClosed else {
                return .stop(entry, .closed, cancelled)
            }
            guard !entry.flag.cancelled else {
                return .stop(entry, .cancelled, cancelled)
            }

            if let receiver = receivers.popEligible(flaggedInto: &cancelled) {
                return .match(
                    Match(sender: entry, receiver: receiver),
                    cancelled
                )
            }

            senders.enqueue(entry)
            return .wait(cancelled)
        }
        mutating func receive(
            _ entry: consuming Async.Waiter.Entry<
                Receive.Signal,
                Ownership.Slot<Element>
            >
        ) -> Receive.Action {
            var cancelled:
                Async.Waiter.Queue.Drain<
                    Async.Waiter.Queue.Flagged<
                        Send.Signal,
                        Ownership.Slot<Element>
                    >
                > = .init()

            guard !isClosed else {
                return .stop(entry, .closed, cancelled)
            }
            guard !entry.flag.cancelled else {
                return .stop(entry, .cancelled, cancelled)
            }

            if let sender = senders.popEligible(flaggedInto: &cancelled) {
                return .match(
                    Match(sender: sender, receiver: entry),
                    cancelled
                )
            }

            receivers.enqueue(entry)
            return .wait(cancelled)
        }
        mutating func close() -> Close {
            var action = Close()
            guard !isClosed else { return action }

            status = .closed
            while let sender = senders.dequeue() {
                action.senders.enqueue(sender)
            }
            while let receiver = receivers.dequeue() {
                action.receivers.enqueue(receiver)
            }
            return action
        }
        mutating func reap(
            send: Send.Type
        ) -> Async.Waiter.Queue.Drain<
            Async.Waiter.Queue.Flagged<
                Send.Signal,
                Ownership.Slot<Element>
            >
        > {
            var cancelled:
                Async.Waiter.Queue.Drain<
                    Async.Waiter.Queue.Flagged<
                        Send.Signal,
                        Ownership.Slot<Element>
                    >
                > = .init()
            senders.reapFlagged(into: &cancelled)
            return cancelled
        }
        mutating func reap(
            receive: Receive.Type
        ) -> Async.Waiter.Queue.Drain<
            Async.Waiter.Queue.Flagged<
                Receive.Signal,
                Ownership.Slot<Element>
            >
        > {
            var cancelled:
                Async.Waiter.Queue.Drain<
                    Async.Waiter.Queue.Flagged<
                        Receive.Signal,
                        Ownership.Slot<Element>
                    >
                > = .init()
            receivers.reapFlagged(into: &cancelled)
            return cancelled
        }
    }

#endif  // !hasFeature(Embedded)
