#if !hasFeature(Embedded)

    extension Async.Channel.Unbounded where Element: ~Copyable {

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

    extension Async.Channel.Unbounded.Ends where Element: ~Copyable {

        public var receiver: Async.Channel<Element>.Unbounded.Receiver {
            _read {
                yield _receiver
            }
            _modify {
                yield &_receiver
            }
        }

        public var sender: Async.Channel<Element>.Unbounded.Sender {
            Async.Channel<Element>.Unbounded.Sender(storage: storage)
        }

        public func close() {
            sender.close()
        }

        public var closed: Bool {
            sender.closed
        }
    }

#endif
