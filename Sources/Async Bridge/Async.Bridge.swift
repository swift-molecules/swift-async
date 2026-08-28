#if !hasFeature(Embedded)

    import Queue
    import Deque
    import Synchronization
    import Column
    import Buffer_Ring_Primitive
    import Storage_Contiguous
    import Memory_Heap
    import Memory_Allocator_Primitive
    import Buffer_Primitive

    extension Async {

        public final class Bridge<Element: ~Copyable & Sendable>: Sendable {
            private let _state: Async.Mutex<State>

            private enum _Take: ~Copyable {
                case element(Element)
                case finished
                case suspend
            }

            struct State: ~Copyable {
                var buffer: Deque<Column.Ring<Element>> = .init()
                var continuation: CheckedContinuation<Void, Never>?
                var isFinished: Bool = false
                #if DEBUG
                    var hasWaitingConsumer: Bool = false
                #endif
            }

            public init() {
                self._state = Async.Mutex(State())
            }
        }
    }

    extension Async.Bridge where Element: ~Copyable {

        public func push(_ element: consuming sending Element) {
            let continuationToResume: CheckedContinuation<Void, Never>? =
                _state.withLock(consuming: element) { state, element in
                    guard !state.isFinished else {
                        _ = consume element
                        return nil
                    }
                    state.buffer.push(consume element, to: .back)
                    if let cont = state.continuation {
                        state.continuation = nil
                        #if DEBUG
                            state.hasWaitingConsumer = false
                        #endif
                        return cont
                    }
                    return nil
                }
            continuationToResume?.resume()
        }

        nonisolated(nonsending)
            public func next() async -> Element?
        {

            let fast: _Take = _state.withLock { state in
                #if DEBUG
                    precondition(
                        !state.hasWaitingConsumer,
                        "Bridge: concurrent next() calls detected - single-consumer invariant violated"
                    )
                #endif

                if let element = state.buffer.pop(from: .front) {
                    return .element(element)
                }
                if state.isFinished {
                    return .finished
                }
                return .suspend
            }

            switch consume fast {
            case .element(let element):
                return element

            case .finished:
                return nil

            case .suspend:
                break
            }

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let shouldResumeImmediately: Bool = _state.withLock { state in

                    if !state.buffer.isEmpty || state.isFinished {
                        return true
                    }
                    state.continuation = continuation
                    #if DEBUG
                        state.hasWaitingConsumer = true
                    #endif
                    return false
                }
                if shouldResumeImmediately {
                    continuation.resume()
                }
            }

            return _state.withLock { state in
                #if DEBUG
                    state.hasWaitingConsumer = false
                #endif
                return state.buffer.pop(from: .front)
            }
        }

        public func finish() {
            let continuationToResume: CheckedContinuation<Void, Never>? = _state.withLock { state in
                state.isFinished = true
                if let cont = state.continuation {
                    state.continuation = nil
                    #if DEBUG
                        state.hasWaitingConsumer = false
                    #endif
                    return cont
                }
                return nil
            }
            continuationToResume?.resume()
        }

        public var isFinished: Bool {
            _state.withLock { $0.isFinished }
        }
    }

    extension Async.Bridge where Element: ~Copyable {

        public func push(draining next: () -> Element?) {
            let continuationToResume: CheckedContinuation<Void, Never>? = _state.withLock { state in
                guard !state.isFinished else { return nil }
                while let element = next() {
                    state.buffer.push(consume element, to: .back)
                }
                if let cont = state.continuation {
                    state.continuation = nil
                    #if DEBUG
                        state.hasWaitingConsumer = false
                    #endif
                    return cont
                }
                return nil
            }
            continuationToResume?.resume()
        }
    }

    extension Async.Bridge where Element: Copyable {

        public func push(_ elements: borrowing [Element]) {
            guard !elements.isEmpty else { return }

            let continuationToResume: CheckedContinuation<Void, Never>? = _state.withLock { state in
                guard !state.isFinished else { return nil }
                for i in 0..<elements.count {
                    state.buffer.push(elements[i], to: .back)
                }
                if let cont = state.continuation {
                    state.continuation = nil
                    #if DEBUG
                        state.hasWaitingConsumer = false
                    #endif
                    return cont
                }
                return nil
            }
            continuationToResume?.resume()
        }

        public func push<S: Swift.Sequence>(contentsOf elements: S) where S.Element == Element {
            let continuationToResume: CheckedContinuation<Void, Never>? = _state.withLock { state in
                guard !state.isFinished else { return nil }
                for element in elements {
                    state.buffer.push(element, to: .back)
                }
                if let cont = state.continuation {
                    state.continuation = nil
                    #if DEBUG
                        state.hasWaitingConsumer = false
                    #endif
                    return cont
                }
                return nil
            }
            continuationToResume?.resume()
        }
    }

#endif
