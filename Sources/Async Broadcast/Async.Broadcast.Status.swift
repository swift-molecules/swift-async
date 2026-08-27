#if !hasFeature(Embedded)

    extension Async.Broadcast {

        @usableFromInline
        enum Is: Sendable {
            case active
            case finished
        }
    }

#endif
