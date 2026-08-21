extension Async.Waiter.Flag {

    public enum Reason: Sendable {

        case cancelled

        case timedOut
    }

    public var reason: Reason? {
        if cancelled { return .cancelled }
        if timedOut { return .timedOut }
        return nil
    }
}
