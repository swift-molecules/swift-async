#if !hasFeature(Embedded)

    extension Async.Channel where Element: ~Copyable {

        public typealias Error = Async._ChannelError
    }

    extension Async {

        public enum _ChannelError: Swift.Error, Sendable, Equatable {

            case closed

            case cancelled

            case full

            case empty
        }
    }

#endif
