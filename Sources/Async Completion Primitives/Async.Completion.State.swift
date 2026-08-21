#if !hasFeature(Embedded)

    public import Synchronization

    extension Async.Completion {

        public enum State: UInt8, AtomicRepresentable, Sendable {

            case pending = 0

            case running = 1

            case completed = 2

            case timedOut = 3

            case cancelled = 4

            case failed = 5
        }
    }

#endif
