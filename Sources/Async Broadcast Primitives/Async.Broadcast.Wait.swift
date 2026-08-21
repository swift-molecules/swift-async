#if !hasFeature(Embedded)

    extension Async.Broadcast {

        struct Wait {

            var token: UInt64 = 0
        }
    }

#endif
