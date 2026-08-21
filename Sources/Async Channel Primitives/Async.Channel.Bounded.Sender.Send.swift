#if !hasFeature(Embedded)

    public import Ownership_Primitives
    import Column_Primitives
    import Buffer_Ring_Primitive
    import Storage_Contiguous_Primitives
    import Memory_Heap_Primitives
    import Memory_Allocator_Primitive
    import Buffer_Primitive

    extension Async.Channel.Bounded.Sender where Element: ~Copyable {

        public struct Send: Sendable {
            @usableFromInline
            let handle: Handle

            @usableFromInline
            init(handle: Handle) {
                self.handle = handle
            }

            @_optimize(none)
            @inlinable
            public func immediate(
                _ element: consuming sending Element
            ) throws(Async.Channel<Element>.Error) {
                let slot = Ownership.Slot(consume element)
                let decision = handle.storage.withLock { state in
                    state.send(slot)
                }

                switch consume decision {
                case .deliverToReceiver(let receiverCont, let element):
                    _ = handle.storage.deliverySlot.store(element)
                    receiverCont.resume(
                        returning: Async.Channel<Element>.Bounded.State.Receive.Signal.delivered
                    )

                case .buffered:
                    break

                case .rejectClosed:
                    throw .closed

                case .suspend:
                    throw .full
                }
            }
        }
    }

#endif
