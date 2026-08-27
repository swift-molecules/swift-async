extension Async.Waiter {

    public struct Resumption: ~Copyable, Sendable {
        @usableFromInline
        let _resume: @Sendable () -> Void

        @inlinable
        public init(_ action: @escaping @Sendable () -> Void) {
            self._resume = action
        }
    }
}

extension Async.Waiter.Resumption {

    @inlinable
    public consuming func resume() {
        _resume()
    }
}
