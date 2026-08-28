#if !hasFeature(Embedded)

    public import Ownership
    import Column
    public import Buffer_Ring_Primitive
    import Storage_Contiguous
    import Memory_Heap
    import Memory_Allocator_Primitive
    import Buffer_Primitive
    public import Deque
    public import Pair

    extension Async.Channel.Unbounded where Element: ~Copyable {

        public struct Sender: Sendable {
            @usableFromInline
            let storage: Storage

            @usableFromInline
            init(storage: Storage) {
                self.storage = storage
            }
        }
    }

    extension Async.Channel.Unbounded.Sender: Equatable where Element: ~Copyable {

        @inlinable
        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.storage === rhs.storage
        }
    }

    extension Async.Channel.Unbounded.Sender where Element: ~Copyable {

        @_optimize(none)
        @inlinable
        public func send(_ element: consuming sending Element) throws(Async.Channel<Element>.Error)
        {
            let slot = Ownership.Slot(consume element)
            let action = storage.withLock { state in
                state.send(slot)
            }

            switch consume action {
            case .give(let cont, let element):
                _ = storage.deliverySlot.store(element)
                cont.resume(
                    returning: Async.Channel<Element>.Unbounded.State.Receive.Signal.delivered
                )

            case .keep:
                break

            case .shut:
                throw .closed
            }
        }

        @inlinable
        public func send<S: Swift.Sequence>(
            contentsOf slots: sending S
        ) throws(Async.Channel<Element>.Error) where S.Element == Ownership.Slot<Element> {
            let batch = Array(slots)
            let deliverySlot = storage.deliverySlot

            var outcome = storage.withLock {
                state -> Pair<Async.Channel<Element>.Unbounded.State.Receive.Continuation?, Bool> in
                var receiverCont: Async.Channel<Element>.Unbounded.State.Receive.Continuation? = nil
                var delivered = false
                for slot in batch {
                    guard !state.isClosed else { return Pair(receiverCont, true) }
                    if !delivered, let cont = state.waiter.take() {
                        _ = deliverySlot.store(slot.take(__unchecked: ()))
                        receiverCont = consume cont
                        delivered = true
                    } else {
                        state.buffer.push(slot.take(__unchecked: ()), to: .back)
                    }
                }
                return Pair(receiverCont, false)
            }

            if let cont = outcome.first.take() {
                cont.resume(
                    returning: Async.Channel<Element>.Unbounded.State.Receive.Signal.delivered
                )
            }
            if outcome.second { throw .closed }
        }
    }

    extension Async.Channel.Unbounded.Sender where Element: ~Copyable {

        public func close() {
            let action = storage.withLock { state in
                state.close()
            }

            switch consume action {
            case .none:
                break

            case .end(let cont):
                cont.resume(returning: .closed)
            }

        }

        public var closed: Bool {
            storage.withLock { $0.isClosed }
        }
    }

#endif
