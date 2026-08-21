#if !hasFeature(Embedded)

    public import Async_Waiter_Primitives
    public import Ownership_Primitives
    internal import Queue_Primitives
    public import Deque_Primitives
    public import Column_Primitives
    public import Buffer_Ring_Primitive
    public import Storage_Contiguous_Primitives
    import Memory_Heap_Primitives
    import Memory_Allocator_Primitive
    import Buffer_Primitive

    extension Async.Channel.Bounded where Element: ~Copyable {

        public struct Sender: Sendable {
            @usableFromInline
            let handle: Handle

            @usableFromInline
            init(storage: Storage) {
                self.handle = Handle(storage: storage)
            }
        }
    }

    extension Async.Channel.Bounded.Sender where Element: ~Copyable {

        @usableFromInline
        final class Handle: Sendable {
            @usableFromInline
            let storage: Async.Channel<Element>.Bounded.Storage

            @usableFromInline
            init(storage: Async.Channel<Element>.Bounded.Storage) {
                self.storage = storage
            }

            deinit {

                var closeAction = storage.withLock { state in
                    state.close()
                }

                if let receiver = closeAction.receiverToResume.take() {
                    receiver.resume(returning: .closed)
                }

                while let continuation = closeAction.sendersToCancel.take(from: .front) {
                    continuation.resume(returning: .closed)
                }
            }
        }
    }

    extension Async.Channel.Bounded.Sender where Element: ~Copyable {

        @_optimize(none)
        @inlinable
        nonisolated(nonsending)
            public func send(
                _ element: consuming sending Element
            ) async throws(Async.Channel<Element>.Error)
        {

            let slot = Ownership.Slot(consume element)
            let decision = handle.storage.withLock { state in
                state.send(slot)
            }

            let flag: Async.Waiter.Flag
            switch consume decision {
            case .deliverToReceiver(let receiverCont, let element):
                _ = handle.storage.deliverySlot.store(element)
                receiverCont.resume(
                    returning: Async.Channel<Element>.Bounded.State.Receive.Signal.delivered
                )
                return

            case .buffered:
                return

            case .rejectClosed:
                throw .closed

            case .suspend(let sendFlag):
                flag = sendFlag
            }

            let error: Async.Channel<Element>.Error? = await withTaskCancellationHandler {
                await unsafe withUnsafeContinuation {
                    (raw: UnsafeContinuation<Async.Channel<Element>.Error?, Never>) in

                    let action = handle.storage.withLock { state in
                        state.suspend(
                            flag: flag,
                            slot: slot,
                            continuation: unsafe Async.Continuation.Unsafe(raw)
                        )
                    }

                    Async.Channel<Element>.Bounded.Storage.handleSend(
                        consume action,
                        storage: handle.storage
                    )
                }
            } onCancel: {
                if flag.cancel() {
                    var cancelled = Deque<
                        Column.Ring<Async.Channel<Element>.Bounded.State.Send.Continuation>
                    >()
                    handle.storage.withLock { state in
                        cancelled = state.reap()
                    }
                    while let cont = cancelled.take(from: .front) {
                        cont.resume(returning: .cancelled)
                    }
                }
            }

            if let error { throw error }
        }

        public var send: Send { Send(handle: handle) }
    }

    extension Async.Channel.Bounded.Sender where Element: ~Copyable {

        public func close() {
            var closeAction = handle.storage.withLock { state in
                state.close()
            }

            if let receiver = closeAction.receiverToResume.take() {
                receiver.resume(returning: .closed)
            }

            while let continuation = closeAction.sendersToCancel.take(from: .front) {
                continuation.resume(returning: .closed)
            }
        }

        public var isClosed: Bool {
            handle.storage.withLock { $0.isClosed }
        }
    }

#endif
