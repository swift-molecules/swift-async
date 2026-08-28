#if !hasFeature(Embedded)

    extension Async.Broadcast {

        public enum Error: Swift.Error, Sendable, Equatable {

            case cancelled
        }
    }

#endif
