#if !hasFeature(Embedded)

    public import Async_Primitive
    public import Async_Lifecycle
    internal import Async_Waiter
    import Synchronization

    extension Async {

        public final class Barrier: Sendable {

            let _state: Async.Mutex<State>

            let parties: Int

            public init(parties: Int) {
                precondition(parties >= 1, "Barrier requires at least 1 party")
                self.parties = parties
                self._state = Async.Mutex(State())
            }
        }
    }

    extension Async.Barrier {

        typealias Outcome = Result<Void, Async.Lifecycle.Error>

        struct WaiterEntry: Sendable {
            let continuation: CheckedContinuation<Outcome, Never>
            let flag: Async.Waiter.Flag
        }

        struct State: Sendable {

            var arrived: Int = 0

            var cancelled: Int = 0

            var asyncWaiters: [UInt64: WaiterEntry] = [:]

            var callbackWaiters: [@Sendable () -> Void] = []

            var nextID: UInt64 = 0

            var released: Bool = false
        }
    }

    extension Async.Barrier {

        public func arrive(_ callback: @escaping @Sendable () -> Void) {
            let action: ResolveAction = _state.withLock { state in
                self.recordArrivalAndResolve(&state, callback: callback)
            }
            action.execute(immediateCallback: callback)
        }

        public var arrived: Int {
            _state.withLock { $0.arrived }
        }

        public var cancelledCount: Int {
            _state.withLock { $0.cancelled }
        }

        public var isReleased: Bool {
            _state.withLock { $0.released }
        }
    }

    extension Async.Barrier {

        nonisolated(nonsending)
            public func arrive() async throws(Async.Lifecycle.Error)
        {
            let flag = Async.Waiter.Flag()

            let outcome: Outcome = await withTaskCancellationHandler {
                await withCheckedContinuation {
                    (continuation: CheckedContinuation<Outcome, Never>) in
                    let action: SuspendAction = _state.withLock { state in
                        if state.released {
                            return .resumeImmediately(.success(()))
                        }

                        if flag.cancelled {
                            return .resumeImmediately(.failure(.cancelled))
                        }

                        state.arrived += 1
                        let needed = self.parties - state.cancelled
                        guard state.arrived >= needed else {

                            let id = state.nextID
                            state.nextID += 1
                            state.asyncWaiters[id] = WaiterEntry(
                                continuation: continuation,
                                flag: flag
                            )
                            return .suspended(id: id)
                        }

                        state.released = true
                        let asyncWaiters = state.asyncWaiters
                        let callbacks = state.callbackWaiters
                        state.asyncWaiters = [:]
                        state.callbackWaiters = []
                        return .release(
                            others: Array(asyncWaiters.values),
                            callbacks: callbacks,
                            mineOutcome: .success(())
                        )
                    }

                    switch action {
                    case .resumeImmediately(let outcome):
                        continuation.resume(returning: outcome)

                    case .release(let others, let callbacks, let mineOutcome):
                        for entry in others {
                            entry.continuation.resume(returning: .success(()))
                        }
                        for cb in callbacks {
                            cb()
                        }
                        continuation.resume(returning: mineOutcome)

                    case .suspended:

                        break
                    }
                }
            } onCancel: {

                guard flag.cancel() else { return }

                let toResume: CheckedContinuation<Outcome, Never>? = self._state.withLock { state in

                    let myID = state.asyncWaiters.first(where: { $1.flag === flag })?.key
                    guard let myID, let entry = state.asyncWaiters.removeValue(forKey: myID) else {

                        return nil
                    }
                    state.arrived -= 1
                    state.cancelled += 1
                    return entry.continuation
                }

                toResume?.resume(returning: .failure(.cancelled))
            }

            switch outcome {
            case .success:
                return

            case .failure(let error):
                throw error
            }
        }
    }

    extension Async.Barrier {

        enum ResolveAction: Sendable {

            case releaseAndRun(callbacks: [@Sendable () -> Void])

            case runImmediate

            case suspended
        }
    }

    extension Async.Barrier.ResolveAction {
        func execute(immediateCallback: @Sendable () -> Void) {
            switch self {
            case .releaseAndRun(let callbacks):
                for cb in callbacks { cb() }
                immediateCallback()

            case .runImmediate:
                immediateCallback()

            case .suspended:
                break
            }
        }
    }

    extension Async.Barrier {

        enum SuspendAction: Sendable {
            case resumeImmediately(Outcome)
            case release(
                others: [WaiterEntry],
                callbacks: [@Sendable () -> Void],
                mineOutcome: Outcome
            )
            case suspended(id: UInt64)
        }

        func recordArrivalAndResolve(
            _ state: inout State,
            callback: @escaping @Sendable () -> Void
        ) -> ResolveAction {
            if state.released {
                return .runImmediate
            }

            state.arrived += 1
            let needed = parties - state.cancelled
            guard state.arrived >= needed else {
                state.callbackWaiters.append(callback)
                return .suspended
            }

            state.released = true
            let asyncWaiters = state.asyncWaiters
            let callbacks = state.callbackWaiters
            state.asyncWaiters = [:]
            state.callbackWaiters = []
            for entry in asyncWaiters.values {
                entry.continuation.resume(returning: .success(()))
            }
            return .releaseAndRun(callbacks: callbacks)
        }
    }

#endif
