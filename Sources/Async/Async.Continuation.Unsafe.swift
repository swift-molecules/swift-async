#if !hasFeature(Embedded)

    extension Async.Continuation {

        @safe
        public struct Unsafe: ~Copyable, @unchecked Sendable {
            @usableFromInline
            let _base: UnsafeContinuation<T, Never>

            @inlinable
            public init(_ base: UnsafeContinuation<T, Never>) {
                unsafe (self._base = base)
            }
        }
    }

    extension Async.Continuation.Unsafe {

        @inlinable
        public consuming func resume(returning value: consuming sending T) {
            unsafe _base.resume(returning: value)
        }
    }

#endif
