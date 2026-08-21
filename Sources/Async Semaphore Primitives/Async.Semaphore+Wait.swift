#if !hasFeature(Embedded)
    public import Async_Primitive
    internal import Async_Mutex_Primitives
    internal import Async_Waiter_Primitives
    internal import Queue_Primitive
    internal import Queue_Primitives

    extension Async.Semaphore {

        nonisolated(nonsending)

            public func wait() async throws(Async.Semaphore.Error)
        {

            enum Action {
                case acquired
                case shutdown
                case suspend
            }

            let action: Action = _state.withLock { state in
                guard state.lifecycle.isOpen else {
                    return .shutdown
                }

                if state.available > 0 {
                    state.available -= 1
                    state.metrics.acquisitions += 1
                    state.metrics.currentOutstanding += 1
                    state.metrics.peakOutstanding = max(
                        state.metrics.peakOutstanding,
                        state.metrics.currentOutstanding
                    )
                    return .acquired
                }

                return .suspend
            }

            switch action {
            case .acquired:
                return

            case .shutdown:
                throw .shutdown

            case .suspend:
                try await suspendForPermit()
            }
        }

        nonisolated(nonsending)

            public func wait(timeout: Duration) async throws(Async.Semaphore.Error)
        {
            enum Action {
                case acquired
                case shutdown
                case suspend
            }

            let action: Action = _state.withLock { state in
                guard state.lifecycle.isOpen else {
                    return .shutdown
                }

                if state.available > 0 {
                    state.available -= 1
                    state.metrics.acquisitions += 1
                    state.metrics.currentOutstanding += 1
                    state.metrics.peakOutstanding = max(
                        state.metrics.peakOutstanding,
                        state.metrics.currentOutstanding
                    )
                    return .acquired
                }

                return .suspend
            }

            switch action {
            case .acquired:
                return

            case .shutdown:
                throw .shutdown

            case .suspend:
                try await suspendForPermit(timeout: timeout)
            }
        }
    }

    extension Async.Semaphore {

        @usableFromInline

        func suspendForPermit() async throws(Async.Semaphore.Error) {
            let flag = Async.Waiter.Flag()

            let outcome: Outcome = await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    _state.withLock { state in

                        if flag.isFlagged {
                            let outcome: Outcome = Async.Precedence.resolve(
                                shutdown: !state.lifecycle.isOpen,
                                cancelled: flag.cancelled,
                                timedOut: flag.timedOut,
                                success: .success(()),
                                onShutdown: .failure(.shutdown),
                                onCancelled: .failure(.cancelled),
                                onTimeout: .failure(.timeout)
                            )

                            switch outcome {
                            case .failure(.cancelled):
                                state.metrics.cancellations += 1

                            case .failure(.timeout):
                                state.metrics.timeouts += 1

                            default:
                                break
                            }
                            continuation.resume(returning: outcome)
                            return
                        }

                        if !state.lifecycle.isOpen {
                            continuation.resume(returning: .failure(.shutdown))
                            return
                        }
                        if state.available > 0 {
                            state.available -= 1
                            state.metrics.acquisitions += 1
                            state.metrics.currentOutstanding += 1
                            state.metrics.peakOutstanding = max(
                                state.metrics.peakOutstanding,
                                state.metrics.currentOutstanding
                            )
                            continuation.resume(returning: .success(()))
                            return
                        }

                        let entry = Async.Waiter.Entry<Outcome, Void>(
                            continuation: Async.Continuation(continuation),
                            flag: flag
                        )
                        state.waiters.enqueue(entry)
                        state.metrics.currentWaiters += 1
                    }
                }
            } onCancel: {
                if flag.cancel() {
                    Task { self.pumpWaiters() }
                }
            }

            switch outcome {
            case .success:
                return

            case .failure(let error):
                throw error
            }
        }

        @usableFromInline

        func suspendForPermit(timeout: Duration) async throws(Async.Semaphore.Error) {
            let flag = Async.Waiter.Flag()

            let timeoutTask = Task {
                do {
                    try await Task.sleep(for: timeout)
                } catch {

                    return
                }
                if flag.timeout() {
                    self.pumpWaiters()
                }
            }

            let outcome: Outcome = await withTaskCancellationHandler {
                await withCheckedContinuation { continuation in
                    _state.withLock { state in

                        if flag.isFlagged {
                            let outcome: Outcome = Async.Precedence.resolve(
                                shutdown: !state.lifecycle.isOpen,
                                cancelled: flag.cancelled,
                                timedOut: flag.timedOut,
                                success: .success(()),
                                onShutdown: .failure(.shutdown),
                                onCancelled: .failure(.cancelled),
                                onTimeout: .failure(.timeout)
                            )

                            switch outcome {
                            case .failure(.cancelled):
                                state.metrics.cancellations += 1

                            case .failure(.timeout):
                                state.metrics.timeouts += 1

                            default:
                                break
                            }
                            continuation.resume(returning: outcome)
                            return
                        }

                        if !state.lifecycle.isOpen {
                            continuation.resume(returning: .failure(.shutdown))
                            return
                        }
                        if state.available > 0 {
                            state.available -= 1
                            state.metrics.acquisitions += 1
                            state.metrics.currentOutstanding += 1
                            state.metrics.peakOutstanding = max(
                                state.metrics.peakOutstanding,
                                state.metrics.currentOutstanding
                            )
                            continuation.resume(returning: .success(()))
                            return
                        }

                        let entry = Async.Waiter.Entry<Outcome, Void>(
                            continuation: Async.Continuation(continuation),
                            flag: flag
                        )
                        state.waiters.enqueue(entry)
                        state.metrics.currentWaiters += 1
                    }
                }
            } onCancel: {
                if flag.cancel() {
                    Task { self.pumpWaiters() }
                }
            }

            timeoutTask.cancel()

            switch outcome {
            case .success:
                return

            case .failure(let error):
                throw error
            }
        }
    }

    extension Async.Semaphore {

        @usableFromInline
        func pumpWaiters() {

            var pending: Async.Waiter.Queue.Drain<Async.Waiter.Resumption> = _state.withLock {
                state in
                let currentLifecycle = state.lifecycle

                var flagged = Async.Waiter.Queue.Drain<
                    Async.Waiter.Queue.Flagged<Outcome, Void>
                >()
                state.waiters.reapFlagged(into: &flagged)

                var reapedCount = 0
                var resumptions = Async.Waiter.Queue.Drain<Async.Waiter.Resumption>()

                while let flaggedEntry = flagged.dequeue() {
                    reapedCount += 1

                    let resumption = flaggedEntry.resumption { reason in

                        let outcome: Outcome = Async.Precedence.resolve(
                            shutdown: currentLifecycle != .open,
                            cancelled: reason == .cancelled,
                            timedOut: reason == .timedOut,
                            success: .success(()),
                            onShutdown: .failure(.shutdown),
                            onCancelled: .failure(.cancelled),
                            onTimeout: .failure(.timeout)
                        )

                        switch outcome {
                        case .failure(.cancelled):
                            state.metrics.cancellations += 1

                        case .failure(.timeout):
                            state.metrics.timeouts += 1

                        default:
                            break
                        }
                        return outcome
                    }

                    resumptions.enqueue(resumption)
                }

                state.metrics.currentWaiters -= reapedCount
                return resumptions
            }

            pending.drain { $0.resume() }
        }
    }
#endif
