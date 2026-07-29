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

    extension Async.Channel where Element: ~Copyable {
        /// An unbuffered channel that pairs senders and receivers directly.
        ///
        /// A send completes only after one receiver accepts its element. The
        /// channel stores no elements between operations. Suspended senders and
        /// receivers are admitted independently in FIFO order.
        ///
        /// `Sender` and `Receiver` are both copyable, Sendable handles. Copies
        /// share one channel and may be used concurrently by multiple tasks.
        ///
        /// Closing is terminal and idempotent. It resumes suspended sends with
        /// ``Async/Channel/Error/closed``, resumes suspended receives with
        /// `nil`, and discards elements belonging to unmatched sends.
        public struct Rendezvous: ~Copyable, Sendable {
            let storage: Storage

            /// A copyable handle for sending elements.
            public let sender: Sender

            /// A copyable handle for receiving elements.
            public let receiver: Receiver

            /// Creates an open rendezvous channel.
            public init() {
                let storage = Storage()
                self.storage = storage
                self.sender = Sender(storage: storage)
                self.receiver = Receiver(storage: storage)
            }
        }
    }

    extension Async.Channel.Rendezvous where Element: ~Copyable {
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
