#if !hasFeature(Embedded)
    import Synchronization
#endif

extension Async {

    public final class Promise<Value: Sendable>: Sendable {
        private let _state: Async.Mutex<State>

        public init() {
            self._state = Async.Mutex(State())
        }
    }
}

extension Async.Promise {
    fileprivate struct State: Sendable {
        var waiters: [Async.Continuation<Value>] = []
        var fulfilled: Value? = nil
    }
}

extension Async.Promise {

    @discardableResult
    public func fulfill(_ value: sending Value) -> Bool {
        let waitersToResume: [Async.Continuation<Value>]? = _state.withLock { state in
            guard state.fulfilled == nil else { return nil }
            state.fulfilled = value
            let waiters = state.waiters
            state.waiters = []
            return waiters
        }
        guard let waiters = waitersToResume else { return false }
        for waiter in waiters {
            waiter.resume(returning: value)
        }
        return true
    }

    public func wait(_ callback: @escaping @Sendable (sending Value) -> Void) {
        let immediateValue: Value? = _state.withLock { state in
            if let value = state.fulfilled {
                return value
            }
            state.waiters.append(Async.Continuation(callback))
            return nil
        }
        if let value = immediateValue {
            callback(value)
        }
    }

    public var isFulfilled: Bool {
        _state.withLock { $0.fulfilled != nil }
    }

    public var fulfilled: Value? {
        _state.withLock { $0.fulfilled }
    }
}

#if !hasFeature(Embedded)
    extension Async.Promise {

        nonisolated(nonsending)
            public func value() async -> Value
        {
            await withCheckedContinuation { continuation in
                let immediateValue: Value? = _state.withLock { state in
                    if let value = state.fulfilled {
                        return value
                    }
                    state.waiters.append(Async.Continuation(continuation))
                    return nil
                }
                if let value = immediateValue {
                    continuation.resume(returning: value)
                }
            }
        }
    }
#endif
