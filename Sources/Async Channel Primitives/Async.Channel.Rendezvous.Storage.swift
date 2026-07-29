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
    import Queue_Primitives

    extension Async.Channel.Rendezvous where Element: ~Copyable {
        /// Synchronized rendezvous storage.
        final class Storage: Sendable {
            let mutex: Async.Mutex<State>
            init() {
                self.mutex = Async.Mutex(State())
            }
        }
    }

    extension Async.Channel.Rendezvous.Storage where Element: ~Copyable {
        func lock<T: ~Copyable, E: Swift.Error>(
            _ body: (inout sending Async.Channel<Element>.Rendezvous.State) throws(E) -> sending T
        ) throws(E) -> sending T {
            try mutex.withLock(body)
        }
        func close() {
            let action = lock { $0.close() }
            Self.handle(action)
        }
        func cancel(
            _ send: Async.Channel<Element>.Rendezvous.State.Send.Type
        ) {
            var cancelled = lock { $0.reap(send: send) }
            cancelled.drain { flagged in
                flagged.resumption(resolving: { _ in .cancelled }).resume()
            }
        }
        func cancel(
            _ receive: Async.Channel<Element>.Rendezvous.State.Receive.Type
        ) {
            var cancelled = lock { $0.reap(receive: receive) }
            cancelled.drain { flagged in
                flagged.resumption(resolving: { _ in .cancelled }).resume()
            }
        }
        static func handle(
            _ action: consuming Async.Channel<Element>.Rendezvous.State.Send.Action
        ) {
            switch consume action {
            case .wait(var cancelled):
                cancelled.drain { flagged in
                    flagged.resumption(resolving: { _ in .cancelled }).resume()
                }

            case .match(let match, var cancelled):
                cancelled.drain { flagged in
                    flagged.resumption(resolving: { _ in .cancelled }).resume()
                }
                transfer(match)

            case .stop(let entry, let signal, var cancelled):
                cancelled.drain { flagged in
                    flagged.resumption(resolving: { _ in .cancelled }).resume()
                }
                entry.resumption(with: signal).resume()
            }
        }
        static func handle(
            _ action: consuming Async.Channel<Element>.Rendezvous.State.Receive.Action
        ) {
            switch consume action {
            case .wait(var cancelled):
                cancelled.drain { flagged in
                    flagged.resumption(resolving: { _ in .cancelled }).resume()
                }

            case .match(let match, var cancelled):
                cancelled.drain { flagged in
                    flagged.resumption(resolving: { _ in .cancelled }).resume()
                }
                transfer(match)

            case .stop(let entry, let signal, var cancelled):
                cancelled.drain { flagged in
                    flagged.resumption(resolving: { _ in .cancelled }).resume()
                }
                entry.resumption(with: signal).resume()
            }
        }
        static func handle(
            _ action: consuming Async.Channel<Element>.Rendezvous.State.Close
        ) {
            var action = consume action
            action.senders.drain { entry in
                entry.resumption(with: .closed).resume()
            }
            action.receivers.drain { entry in
                entry.resumption(with: .closed).resume()
            }
        }
        static func transfer(
            _ match: consuming Async.Channel<Element>.Rendezvous.State.Match
        ) {
            let match = consume match
            guard let element = match.sender.metadata.take() else {
                preconditionFailure("Rendezvous sender completed without an element")
            }
            guard match.receiver.metadata.store(element) == nil else {
                preconditionFailure("Rendezvous receiver slot was already occupied")
            }

            let receiver = match.receiver.resumption(with: .element)
            let sender = match.sender.resumption(with: .sent)
            receiver.resume()
            sender.resume()
        }
    }

#endif  // !hasFeature(Embedded)
