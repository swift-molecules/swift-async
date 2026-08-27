#if !hasFeature(Embedded)

    extension Async.Channel where Element: ~Copyable {

        public struct Unbounded: ~Copyable, Sendable {
            @usableFromInline
            let storage: Storage

            public let sender: Sender

            public var receiver: Receiver

            public init() {
                let storage = Storage()
                self.storage = storage
                self.sender = Sender(storage: storage)
                self.receiver = Receiver(storage: storage)
            }
        }
    }

    extension Async.Channel.Unbounded where Element: ~Copyable {

        public consuming func take() -> Take {
            Take(channel: consume self)
        }
    }

    extension Async.Channel.Unbounded where Element: ~Copyable {

        public func close() {
            sender.close()
        }

        public var closed: Bool {
            storage.withLock { $0.isClosed }
        }
    }

#endif
