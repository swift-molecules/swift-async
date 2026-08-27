extension Async.Waiter.Queue {

    public struct Flagged<Outcome: Sendable, Metadata: ~Copyable & Sendable>: ~Copyable, Sendable {

        public let reason: Async.Waiter.Flag.Reason

        public var entry: Async.Waiter.Entry<Outcome, Metadata>

        @inlinable
        public init(
            reason: Async.Waiter.Flag.Reason,
            entry: consuming Async.Waiter.Entry<Outcome, Metadata>
        ) {
            self.reason = reason
            self.entry = entry
        }

        @frozen
        public struct Split: ~Copyable, Sendable {

            public let reason: Async.Waiter.Flag.Reason

            public var entry: Async.Waiter.Entry<Outcome, Metadata>

            @inlinable
            public init(
                reason: Async.Waiter.Flag.Reason,
                entry: consuming Async.Waiter.Entry<Outcome, Metadata>
            ) {
                self.reason = reason
                self.entry = entry
            }
        }
    }
}

extension Async.Waiter.Queue.Flagged {

    @inlinable
    public consuming func split() -> Split {
        Split(reason: reason, entry: entry)
    }
}

extension Async.Waiter.Queue.Flagged {

    public consuming func resumption(
        resolving makeOutcome: (Async.Waiter.Flag.Reason) -> Outcome
    ) -> Async.Waiter.Resumption {
        let split = self.split()
        return split.entry.resumption(with: makeOutcome(split.reason))
    }
}
