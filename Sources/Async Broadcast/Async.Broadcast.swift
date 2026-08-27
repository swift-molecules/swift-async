#if !hasFeature(Embedded)

    import Dictionary
    import Dictionary_Ordered
    import Hash_Indexed_Primitive
    import Hash
    import Queue
    import Deque
    import Column
    import Buffer_Ring_Primitive
    import Buffer_Linear_Primitive
    import Storage_Contiguous
    import Memory_Heap
    import Memory_Allocator_Primitive
    import Buffer_Primitive
    import Index
    import Synchronization

    extension Async {

        public final class Broadcast<Element: Sendable>: Sendable {
            let _state: Async.Mutex<State>
            private let buffer: Buffer
            private let onLoss: (@Sendable (Loss) -> Void)?

            public init(bufferCapacity: Int = 64, onLoss: (@Sendable (Loss) -> Void)? = nil) {
                precondition(
                    bufferCapacity > 0,
                    "Broadcast buffer capacity must be greater than zero"
                )
                self.buffer = Buffer(limit: .init(Cardinal(UInt(bufferCapacity))))
                self._state = Async.Mutex(State())
                self.onLoss = onLoss
            }

        }
    }

    extension Async.Broadcast {

        public func send(_ element: sending Element) {
            let bufferLimit = buffer.limit
            let (continuationsToResume, lossEvents):
                (
                    [(CheckedContinuation<Next.Outcome, Never>, Element)], [Loss]
                ) = _state.withLock { state in
                    guard state.is == .active else { return ([], []) }

                    let index = state.next.index
                    state.next.index += 1

                    state.buffer.push((index, element), to: .back)

                    var droppedThroughIndex: UInt64? = nil
                    while state.buffer.count > bufferLimit {
                        guard let front = state.buffer.take(from: .front) else { break }
                        droppedThroughIndex = front.index
                    }

                    var lossEvents: [Loss] = []
                    if let droppedThroughIndex {
                        let floor = droppedThroughIndex + 1
                        var laggingIds: [UInt64] = []
                        state.subscribers.forEach { id, subscriber in
                            if subscriber.cursor < floor {
                                laggingIds.append(id)
                            }
                        }
                        for id in laggingIds {
                            _ = state.subscribers.withMutableValue(forKey: id) { subscriber in
                                let droppedCount = Int(floor - subscriber.cursor)
                                lossEvents.append(
                                    Loss(
                                        subscriberID: id,
                                        droppedCount: droppedCount,
                                        resumingAtIndex: floor,
                                        reason: .capacityLimit
                                    )
                                )
                                subscriber.cursor = floor
                            }
                        }
                    }

                    var toResume: [(CheckedContinuation<Next.Outcome, Never>, Element)] = []
                    var wakeIds: [UInt64] = []
                    state.subscribers.forEach { id, subscriber in
                        if subscriber.cursor == index, subscriber.continuation != nil {
                            wakeIds.append(id)
                        }
                    }

                    for id in wakeIds {
                        _ = state.subscribers.withMutableValue(forKey: id) { subscriber in
                            if let cont = subscriber.continuation {
                                subscriber.cursor = index + 1
                                subscriber.continuation = nil
                                toResume.append((cont, element))
                            }
                        }
                    }
                    return (toResume, lossEvents)
                }

            if let onLoss {
                for event in lossEvents {
                    onLoss(event)
                }
            }

            for (continuation, element) in continuationsToResume {
                continuation.resume(returning: .element(element))
            }
        }

        public func finish() {
            let continuationsToResume: [CheckedContinuation<Next.Outcome, Never>] = _state.withLock
            { state in
                state.is = .finished

                var toResume: [CheckedContinuation<Next.Outcome, Never>] = []
                var finishIds: [UInt64] = []
                state.subscribers.forEach { id, subscriber in
                    if subscriber.continuation != nil {
                        let cursor = subscriber.cursor
                        var hasBufferedElement = false
                        state.buffer.forEach { entry in
                            if entry.index >= cursor { hasBufferedElement = true }
                        }
                        if !hasBufferedElement {
                            finishIds.append(id)
                        }
                    }
                }

                for id in finishIds {
                    _ = state.subscribers.withMutableValue(forKey: id) { subscriber in
                        if let cont = subscriber.continuation {
                            subscriber.continuation = nil
                            toResume.append(cont)
                        }
                    }
                }
                return toResume
            }

            for continuation in continuationsToResume {
                continuation.resume(returning: .finished)
            }
        }

        public var isFinished: Bool {
            _state.withLock { $0.is == .finished }
        }
    }

    extension Async.Broadcast {

        public func subscribe() -> Subscription {
            let id = _state.withLock { state -> UInt64 in
                state.subscriber.seed += 1
                let id = state.subscriber.seed
                let cursor = state.next.index
                state.subscribers.insert(
                    key: id,
                    value: Subscriber(cursor: cursor, continuation: nil)
                )
                return id
            }
            return Subscription(broadcast: self, id: id)
        }

    }

#endif
