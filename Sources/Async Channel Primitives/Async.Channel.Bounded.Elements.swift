#if !hasFeature(Embedded)

    extension Async.Channel.Bounded {

        public struct Elements: AsyncSequence, Sendable {
            @usableFromInline
            let storage: Storage

            @usableFromInline
            init(storage: Storage) {
                self.storage = storage
            }
        }
    }

    extension Async.Channel.Bounded.Elements {

        public func makeAsyncIterator() -> Iterator {
            Iterator(storage: storage)
        }
    }

#endif
