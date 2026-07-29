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

    extension Async.Channel.Rendezvous where Element: ~Copyable {
        /// A copyable handle for receiving elements from a rendezvous channel.
        public struct Receiver: Sendable {
            let storage: Storage
            init(storage: Storage) {
                self.storage = storage
            }
        }
    }

    extension Async.Channel.Rendezvous.Receiver where Element: ~Copyable {
        /// Receives one element from a sender.
        ///
        /// The operation suspends while no sender is waiting.
        ///
        /// - Returns: The accepted element, or `nil` after the channel closes.
        /// - Throws: ``Async/Channel/Error/cancelled`` if this operation is
        ///   cancelled before it accepts an element or observes close.
        nonisolated(nonsending)
            public func receive() async throws(Async.Channel<Element>.Error) -> sending Element?
        {
            guard !Task.isCancelled else { throw .cancelled }

            let flag = Async.Waiter.Flag()
            let slot = Ownership.Slot<Element>()
            let signal: Async.Channel<Element>.Rendezvous.State.Receive.Signal =
                await withTaskCancellationHandler {
                    await withCheckedContinuation { continuation in
                        let entry = Async.Waiter.Entry(
                            continuation: Async.Continuation(continuation),
                            flag: flag,
                            metadata: slot
                        )
                        let entrySlot = Ownership.Slot(entry)
                        let action = storage.lock { state in
                            guard let entry = entrySlot.take() else {
                                preconditionFailure("Rendezvous receive entry was already consumed")
                            }
                            return state.receive(entry)
                        }
                        Async.Channel<Element>.Rendezvous.Storage.handle(action)
                    }
                } onCancel: {
                    if flag.cancel() {
                        storage.cancel(Async.Channel<Element>.Rendezvous.State.Receive.self)
                    }
                }

            switch signal {
            case .element:
                guard let element = slot.take() else {
                    preconditionFailure("Rendezvous receive completed without an element")
                }
                return element

            case .closed:
                return nil

            case .cancelled:
                throw .cancelled
            }
        }

        /// Whether the channel has been closed.
        public var isClosed: Bool {
            storage.lock { $0.isClosed }
        }
    }

#endif  // !hasFeature(Embedded)
