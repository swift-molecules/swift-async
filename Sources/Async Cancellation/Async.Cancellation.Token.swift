extension Async.Cancellation {

    public struct Token: Sendable {
        @usableFromInline
        let source: Async.Cancellation.Source

        @usableFromInline
        init(source: Async.Cancellation.Source) {
            self.source = source
        }
    }
}

extension Async.Cancellation.Token {

    @inlinable
    public var isCancelled: Bool {
        self.source.isCancelled
    }

    @inlinable
    public func checkCancellation() throws(Async.Cancellation.Error) {
        if self.source.isCancelled {
            throw .cancelled
        }
    }
}

extension Async.Cancellation.Token {

    @inlinable
    @discardableResult
    public func onCancel(
        _ handler: @escaping @Sendable () -> Void
    ) -> Async.Cancellation.Registration {
        self.source.onCancel(handler)
    }
}
