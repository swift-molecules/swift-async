#if !hasFeature(Embedded)
    import Synchronization
#endif

extension Async {

    public final class Publication<Value: Sendable>: Sendable {
        private let _state: Async.Mutex<Value?>

        public init(_ initial: sending Value? = nil) {
            self._state = Async.Mutex(initial)
        }
    }
}

extension Async.Publication {

    public func publish(_ value: sending Value) {
        _state.withLock { $0 = value }
    }

    public func take() -> Value? {
        _state.withLock { current in
            let value = current
            current = nil
            return value
        }
    }
}
