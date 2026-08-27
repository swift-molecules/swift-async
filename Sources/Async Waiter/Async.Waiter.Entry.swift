extension Async.Waiter {

    public struct Entry<Outcome: Sendable, Metadata: ~Copyable & Sendable>: ~Copyable, Sendable {

        public let continuation: Async.Continuation<Outcome>

        public let flag: Async.Waiter.Flag

        public var metadata: Metadata

        @inlinable
        public init(
            continuation: Async.Continuation<Outcome>,
            flag: Async.Waiter.Flag,
            metadata: consuming Metadata
        ) {
            self.continuation = continuation
            self.flag = flag
            self.metadata = metadata
        }
    }
}

extension Async.Waiter.Entry {

    @inlinable
    public consuming func resumption(with outcome: Outcome) -> Async.Waiter.Resumption {
        let cont = self.continuation
        _ = consume self
        return Async.Waiter.Resumption {
            cont.resume(returning: outcome)
        }
    }
}

extension Async.Waiter.Entry where Metadata == Void {

    @inlinable
    public init(
        continuation: Async.Continuation<Outcome>,
        flag: Async.Waiter.Flag
    ) {
        self.continuation = continuation
        self.flag = flag
        self.metadata = ()
    }
}
