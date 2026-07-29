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
        /// A copyable handle for sending elements to a rendezvous channel.
        public struct Sender: Sendable {
            let storage: Storage
            init(storage: Storage) {
                self.storage = storage
            }
        }
    }

    extension Async.Channel.Rendezvous.Sender where Element: ~Copyable {
        /// Sends an element after one receiver accepts it.
        ///
        /// The operation suspends while no receiver is waiting.
        ///
        /// - Parameter element: The element transferred to one receiver.
        /// - Throws: ``Async/Channel/Error/closed`` if the channel closes before
        ///   the element is accepted, or ``Async/Channel/Error/cancelled`` if
        ///   this operation is cancelled first.
        nonisolated(nonsending)
            public func send(
                _ element: consuming sending Element
            ) async throws(Async.Channel<Element>.Error)
        {
            guard !Task.isCancelled else { throw .cancelled }

            let flag = Async.Waiter.Flag()
            let slot = Ownership.Slot(consume element)
            let signal: Async.Channel<Element>.Rendezvous.State.Send.Signal =
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
                                preconditionFailure("Rendezvous send entry was already consumed")
                            }
                            return state.send(entry)
                        }
                        Async.Channel<Element>.Rendezvous.Storage.handle(action)
                    }
                } onCancel: {
                    if flag.cancel() {
                        storage.cancel(Async.Channel<Element>.Rendezvous.State.Send.self)
                    }
                }

            switch signal {
            case .sent:
                return

            case .closed:
                throw .closed

            case .cancelled:
                throw .cancelled
            }
        }

        /// Closes the channel.
        public func close() {
            storage.close()
        }

        /// Whether the channel has been closed.
        public var isClosed: Bool {
            storage.lock { $0.isClosed }
        }
    }

#endif  // !hasFeature(Embedded)
