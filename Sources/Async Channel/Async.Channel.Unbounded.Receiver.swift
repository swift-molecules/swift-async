#if !hasFeature(Embedded)

    public import Ownership
    internal import Queue
    import Column
    import Buffer_Ring_Primitive
    import Storage_Contiguous
    import Memory
    import Memory_Allocator_Primitive
    import Buffer_Primitive

    extension Async.Channel.Unbounded where Element: ~Copyable {

        public struct Receiver: ~Copyable, Sendable {
            @usableFromInline
            let storage: Storage

            @usableFromInline
            init(storage: Storage) {
                self.storage = storage
            }
        }
    }

    extension Async.Channel.Unbounded.Receiver where Element: ~Copyable {

        @_optimize(none)
        @inlinable
        nonisolated(nonsending)
            public func receive() async throws(Async.Channel<Element>.Error) -> sending Element?
        {

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

        @inlinable
        public func poll() -> sending Element? {
            storage.withLock { state in
                state.poll()
            }
        }
    }

    extension Async.Channel.Unbounded.Receiver where Element: ~Copyable {

        public var closed: Bool {
            storage.withLock { $0.isClosed }
        }
    }

    extension Async.Channel.Unbounded.Receiver {

        public var elements: Async.Channel<Element>.Unbounded.Elements {
            Async.Channel<Element>.Unbounded.Elements(storage: storage)
        }
    }

#endif
