extension Async.Cancellation {

    public enum State: Sendable, Equatable {

        case active

        case cancelled
    }
}

extension Async.Cancellation.State {

    @inlinable
    public var isCancelled: Bool {
        self == .cancelled
    }
}

extension Async.Cancellation.State {

    @inlinable
    @discardableResult
    public mutating func cancel() -> Bool {
        guard self == .active else { return false }
        self = .cancelled
        return true
    }
}
