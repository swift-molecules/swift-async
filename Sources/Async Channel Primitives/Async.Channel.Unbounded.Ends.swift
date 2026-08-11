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

    extension Async._Channel.Unbounded where Element: ~Copyable {
        /// Bundle containing both sender and receiver.
        ///
        /// `Ends` is `~Copyable` because it contains the `~Copyable` receiver.
        /// Use `channel.take.ends` to consume the channel and obtain this bundle.
        public struct Ends: ~Copyable, Sendable {
            @usableFromInline
            let storage: Storage

            @usableFromInline
            var _receiver: Receiver

            @usableFromInline
            init(storage: Storage, receiver: consuming Receiver) {
                self.storage = storage
                self._receiver = receiver
            }
        }
    }

    extension Async._Channel.Unbounded.Ends where Element: ~Copyable {
        /// View for receiving elements.
        public var receiver: Async._Channel<Element>.Unbounded.Receiver {
            _read {
                yield _receiver
            }
            _modify {
                yield &_receiver
            }
        }

        /// View for sending elements.
        public var sender: Async._Channel<Element>.Unbounded.Sender {
            Async._Channel<Element>.Unbounded.Sender(storage: storage)
        }

        /// Close the channel.
        public func close() {
            sender.close()
        }

        /// Whether the channel has been closed.
        public var closed: Bool {
            sender.closed
        }
    }

#endif  // !hasFeature(Embedded)
