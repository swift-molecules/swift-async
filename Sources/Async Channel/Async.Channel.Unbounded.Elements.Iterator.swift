#if !hasFeature(Embedded)

    public import Ownership
    import Column
    import Buffer_Ring_Primitive
    import Storage_Contiguous
    import Memory
    import Memory_Allocator_Primitive
    import Buffer_Primitive

    extension Async.Channel.Unbounded.Elements {

        public struct Iterator: AsyncIteratorProtocol, Sendable {
            @usableFromInline
            let storage: Async.Channel<Element>.Unbounded.Storage

            @usableFromInline
            init(storage: Async.Channel<Element>.Unbounded.Storage) {
                self.storage = storage
            }
        }
    }

    extension Async.Channel.Unbounded.Elements.Iterator {

        @_optimize(none)
        @inlinable
        nonisolated(nonsending)
            public mutating func next() async throws(Async.Channel<Element>.Error) -> Element?
        {

            let storage = self.storage

            let fastAction = storage.withLock { state in
                state.receive()
            }

            switch consume fastAction {
            case .val(let element, _):
                return element

            case .end:
                return nil

            case .wait:
                break

            case .cancelled:
                throw .cancelled
            }

            if Task.isCancelled {
                throw .cancelled
            }

            let signal: Async.Channel<Element>.Unbounded.State.Receive.Signal =
                await withTaskCancellationHandler {
                    await unsafe withUnsafeContinuation {
                        (
                            raw: UnsafeContinuation<
                                Async.Channel<Element>.Unbounded.State.Receive.Signal, Never
                            >
                        ) in

                        let action = storage.withLock { state in
                            state.wait(unsafe Async.Continuation.Unsafe(raw))
                        }

                        Async.Channel<Element>.Unbounded.Storage.handleReceive(
                            consume action,
                            storage: storage
                        )
                    }
                } onCancel: {
                    let stopAction = storage.withLock { state in
                        state.stop()
                    }

                    switch consume stopAction {
                    case .stop(let cont):
                        cont.resume(returning: .cancelled)

                    case .none:
                        break
                    }
                }

            switch signal {
            case .delivered: return storage.deliverySlot.take()
            case .closed: return nil
            case .cancelled: throw .cancelled
            }
        }
    }

#endif
