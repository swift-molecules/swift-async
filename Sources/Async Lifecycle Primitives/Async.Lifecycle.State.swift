extension Async.Lifecycle {

    public enum State: Sendable, Equatable {

        case open

        case closing

        case closed
    }
}

extension Async.Lifecycle.State {

    @inlinable
    public var isOpen: Bool {
        self == .open
    }
}
