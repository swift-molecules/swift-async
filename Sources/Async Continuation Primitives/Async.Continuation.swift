extension Async {
    #if !hasFeature(Embedded)

        public struct Continuation<T: Sendable>: Sendable {
            @usableFromInline
            let storage: Storage

            @inlinable
            public init(_ continuation: CheckedContinuation<T, Never>) {
                self.storage = .checkedContinuation(continuation)
            }
        }
    #else

        public struct Continuation<T: Sendable>: Sendable {
            @usableFromInline
            let callback: @Sendable (sending T) -> Void

            @inlinable
            public init(_ callback: @escaping @Sendable (sending T) -> Void) {
                self.callback = callback
            }
        }
    #endif
}

#if !hasFeature(Embedded)
    extension Async.Continuation {

        @inlinable
        public init(_ callback: @escaping @Sendable (sending T) -> Void) {
            self.storage = .callback(callback)
        }

        @inlinable
        public func resume(returning value: consuming T) {
            switch storage {
            case .checkedContinuation(let continuation):
                continuation.resume(returning: value)

            case .callback(let callback):
                callback(value)
            }
        }
    }
#else
    extension Async.Continuation {

        @inlinable
        public func resume(returning value: consuming T) {
            callback(value)
        }
    }
#endif
