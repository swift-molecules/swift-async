#if !hasFeature(Embedded)

    import Synchronization
    public import Ownership_Primitives
    import Column_Primitives
    public import Buffer_Ring_Primitive
    import Storage_Contiguous_Primitives
    import Memory_Heap_Primitives
    import Memory_Allocator_Primitive
    import Buffer_Primitive
    internal import Deque_Primitives

    extension Async.Channel.Bounded where Element: ~Copyable {

        @usableFromInline
        struct Storage: Sendable {
            @usableFromInline
            let _storage: Ownership.Mutable<Async.Mutex<State>>.Unchecked

            @usableFromInline
            let deliverySlot: Ownership.Slot<Element>

            @usableFromInline
            init(capacity: Index<Element>.Count) {
                self._storage = Ownership.Mutable.Unchecked(Async.Mutex(State(capacity: capacity)))
                self.deliverySlot = Ownership.Slot()
            }
        }
    }

    extension Async.Channel.Bounded.Storage where Element: ~Copyable {
        @inlinable
        func withLock<T: ~Copyable, E: Swift.Error>(
            _ body: (inout sending Async.Channel<Element>.Bounded.State) throws(E) -> sending T
        ) throws(E) -> sending T {
            try _storage.mutable.value.withLock(body)
        }

        @_optimize(none)
        @usableFromInline
        static func handleReceive(
            _ action: consuming sending Async.Channel<Element>.Bounded.State.Receive.Action,
            storage: Async.Channel<Element>.Bounded.Storage
        ) {

            switch consume action {
            case .returnElement(let element, let resumeSender, let cancelled, let receiver):
                if var cancelled {
                    while let c = cancelled.take(from: .front) {
                        c.resume(returning: .cancelled)
                    }
                }
                if let resumeSender { resumeSender.resume(returning: nil) }
                _ = storage.deliverySlot.store(element)
                if let receiver { receiver.resume(returning: .delivered) }

            case .returnNil(let receiver):
                if let receiver { receiver.resume(returning: .closed) }

            case .rejectCancelled(let receiver):
                if let receiver { receiver.resume(returning: .cancelled) }

            case .suspend:
                break
            }
        }

        @_optimize(none)
        @usableFromInline
        static func handleSend(
            _ action: consuming sending Async.Channel<Element>.Bounded.State.Send.Action,
            storage: Async.Channel<Element>.Bounded.Storage
        ) {

            switch consume action {
            case .deliverToReceiver(let receiverCont, let element, let sender):
                _ = storage.deliverySlot.store(element)
                receiverCont.resume(
                    returning: Async.Channel<Element>.Bounded.State.Receive.Signal.delivered
                )
                sender.resume(returning: nil)

            case .buffered(let sender):
                sender.resume(returning: nil)

            case .rejectClosed(let sender):
                sender.resume(returning: .closed)

            case .rejectCancelled(let sender):
                sender.resume(returning: .cancelled)

            case .suspended:
                break
            }
        }
    }

#endif
