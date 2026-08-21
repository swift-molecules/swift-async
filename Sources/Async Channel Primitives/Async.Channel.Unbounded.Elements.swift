#if !hasFeature(Embedded)

    extension Async.Channel.Unbounded {

        public struct Elements: AsyncSequence, Sendable {
            @usableFromInline
            let storage: Storage

            @usableFromInline
            init(storage: Storage) {
                self.storage = storage
            }
        }
    }

    extension Async.Channel.Unbounded.Elements {

        public func makeAsyncIterator() -> Iterator {
            Iterator(storage: storage)
        }
    }

#endif
