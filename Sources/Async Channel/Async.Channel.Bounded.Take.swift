#if !hasFeature(Embedded)

    extension Async.Channel.Bounded where Element: ~Copyable {

        public struct Take: ~Copyable, Sendable {
            @usableFromInline
            var channel: Async.Channel<Element>.Bounded

            @usableFromInline
            init(channel: consuming Async.Channel<Element>.Bounded) {
                self.channel = channel
            }

            public consuming func ends() -> Ends {
                let storage = channel.storage
                let receiver = consume channel.receiver
                return Ends(storage: storage, receiver: receiver)
            }
        }
    }

#endif
