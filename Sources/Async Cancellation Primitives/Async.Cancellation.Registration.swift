extension Async.Cancellation {

    public struct Registration: Sendable {
        @usableFromInline
        let source: Async.Cancellation.Source

        @usableFromInline
        let identifier: UInt64?

        @usableFromInline
        init(source: Async.Cancellation.Source, identifier: UInt64?) {
            self.source = source
            self.identifier = identifier
        }
    }
}

extension Async.Cancellation.Registration {

    @discardableResult
    public func deregister() -> Bool {
        guard let identifier = self.identifier else { return false }
        return self.source._deregister(identifier)
    }
}
