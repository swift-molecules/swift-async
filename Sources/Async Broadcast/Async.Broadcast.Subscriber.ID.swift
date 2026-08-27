#if !hasFeature(Embedded)

    extension Async.Broadcast.Subscriber {

        struct ID {
            var seed: UInt64 = 0
        }
    }

#endif
