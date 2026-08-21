#if !hasFeature(Embedded)
    public import Index_Primitives

    extension Async.Channel where Element: ~Copyable {

        public struct Bounded: ~Copyable, Sendable {
            @usableFromInline
            let storage: Storage

            public let sender: Sender

            public var receiver: Receiver

            public init(capacity: Index<Element>.Count) {
                precondition(capacity > .zero, "Bounded channel capacity must be greater than zero")
                let storage = Storage(capacity: capacity)
                self.storage = storage
                self.sender = Sender(storage: storage)
                self.receiver = Receiver(storage: storage)
            }
        }
    }

    extension Async.Channel.Bounded where Element: ~Copyable {

        public consuming func take() -> Take {
            Take(channel: consume self)
        }
    }

    extension Async.Channel.Bounded where Element: ~Copyable {

        public func close() {
            sender.close()
        }

        public var isClosed: Bool {
            storage.withLock { $0.isClosed }
        }
    }

#endif
