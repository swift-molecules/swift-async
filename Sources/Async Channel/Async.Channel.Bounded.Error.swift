#if !hasFeature(Embedded)

    extension Async.Channel.Bounded where Element: ~Copyable {

        public typealias Error = Async.Channel<Element>.Error
    }

#endif
