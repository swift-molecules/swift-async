#if !hasFeature(Embedded)

    import Queue_Primitives
    public import Ownership_Primitives
    import Column_Primitives
    public import Buffer_Ring_Primitive
    public import Storage_Contiguous_Primitives
    import Memory_Heap_Primitives
    import Memory_Allocator_Primitive
    import Buffer_Primitive
    public import Deque_Primitives

    extension Async.Channel.Bounded where Element: ~Copyable {

        public struct Receiver: ~Copyable, Sendable {
            @usableFromInline
            let storage: Storage

            @usableFromInline
            init(storage: Storage) {
                self.storage = storage
            }
        }
    }

    extension Async.Channel.Bounded.Receiver where Element: ~Copyable {

        @_optimize(none)
        @inlinable
        nonisolated(nonsending)
            public func receive() async throws(Async.Channel<Element>.Error) -> sending Element?
        {

            let fastAction = storage.withLock { state in
                state.receive()
            }

            switch consume fastAction {
            case .returnElement(let element, let resumeSender, let cancelled, _):

                if var cancelled {
                    while let c = cancelled.take(from: .front) {
                        c.resume(returning: .cancelled)
                    }
                }
                if let resumeSender { resumeSender.resume(returning: nil) }
                return element

            case .returnNil:
                return nil

            case .rejectCancelled:
                throw .cancelled

            case .suspend:
                break
            }

            let signal: Async.Channel<Element>.Bounded.State.Receive.Signal =
                await withTaskCancellationHandler {
                    await unsafe withUnsafeContinuation {
                        (
                            raw: UnsafeContinuation<
                                Async.Channel<Element>.Bounded.State.Receive.Signal, Never
                            >
                        ) in

                        let action = storage.withLock { state in
                            state.suspend(continuation: unsafe Async.Continuation.Unsafe(raw))
                        }
                        Async.Channel<Element>.Bounded.Storage.handleReceive(
                            consume action,
                            storage: storage
                        )
                    }
                } onCancel: {
                    let action = storage.withLock { state in
                        state.cancel()
                    }
                    switch consume action {
                    case .resumeWithCancellation(let continuation):
                        continuation.resume(returning: .cancelled)

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

        public var receive: Receive { Receive(storage: storage) }
    }

    extension Async.Channel.Bounded.Receiver where Element: ~Copyable {

        public var isClosed: Bool {
            storage.withLock { $0.isClosed }
        }
    }

    extension Async.Channel.Bounded.Receiver {

        public var elements: Async.Channel<Element>.Bounded.Elements {
            Async.Channel<Element>.Bounded.Elements(storage: storage)
        }
    }

#endif
