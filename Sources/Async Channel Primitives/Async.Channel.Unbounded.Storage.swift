#if !hasFeature(Embedded)

    import Synchronization
    public import Ownership_Primitives
    import Column_Primitives
    import Buffer_Ring_Primitive
    import Storage_Contiguous_Primitives
    import Memory_Heap_Primitives
    import Memory_Allocator_Primitive
    import Buffer_Primitive

    extension Async.Channel.Unbounded where Element: ~Copyable {

        @usableFromInline
        final class Storage: Sendable {
            @usableFromInline
            let mutex: Async.Mutex<State>

            @usableFromInline
            let deliverySlot: Ownership.Slot<Element>

            @usableFromInline
            init() {
                self.mutex = Async.Mutex(State())
                self.deliverySlot = Ownership.Slot()
            }

            deinit {
                let action = withLock { state in
                    state.close()
                }

                switch consume action {
                case .none:
                    break

                case .end(let cont):
                    cont.resume(returning: .closed)
                }
            }
        }
    }

    extension Async.Channel.Unbounded.Storage where Element: ~Copyable {
        @inlinable
        func withLock<T: ~Copyable, E: Swift.Error>(
            _ body: (inout sending Async.Channel<Element>.Unbounded.State) throws(E) -> sending T
        ) throws(E) -> sending T {
            try mutex.withLock(body)
        }

        @_optimize(none)
        @usableFromInline
        static func handleReceive(
            _ action: consuming sending Async.Channel<Element>.Unbounded.State.Receive.Step,
            storage: Async.Channel<Element>.Unbounded.Storage
        ) {

            switch consume action {
            case .val(let element, let receiver):
                _ = storage.deliverySlot.store(element)
                if let receiver { receiver.resume(returning: .delivered) }

            case .end(let receiver):
                if let receiver { receiver.resume(returning: .closed) }

            case .wait:
                break

            case .cancelled(let receiver):
                if let receiver { receiver.resume(returning: .cancelled) }
            }
        }
    }

#endif
