#if !hasFeature(Embedded)

    extension Async.Channel.Bounded where Element: ~Copyable {

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

    extension Async.Channel.Bounded.Ends where Element: ~Copyable {

        public var receiver: Async.Channel<Element>.Bounded.Receiver {
            _read {
                yield _receiver
            }
            _modify {
                yield &_receiver
            }
        }

        public var sender: Async.Channel<Element>.Bounded.Sender {
            Async.Channel<Element>.Bounded.Sender(storage: storage)
        }

        public func close() {
            sender.close()
        }

        public var isClosed: Bool {
            sender.isClosed
        }
    }

#endif
