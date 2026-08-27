#if !hasFeature(Embedded)
    extension Async.Continuation {
        @usableFromInline
        enum Storage: Sendable {
            case checkedContinuation(CheckedContinuation<T, Never>)
            case callback(@Sendable (sending T) -> Void)
        }
    }
#endif
