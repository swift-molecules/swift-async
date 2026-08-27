#if !hasFeature(Embedded)

    extension Async.Broadcast {

        struct Subscriber {

            var cursor: UInt64

            var wait: Wait = .init()

            var continuation: CheckedContinuation<Next.Outcome, Never>?
        }

    }

#endif
