internal import Async_Mutex_Primitives
public import Async_Primitive
public import Async_Waiter_Primitives
internal import Buffer_Ring_Primitive
internal import Memory_Allocator_Primitive
internal import Memory_Heap_Primitives
public import Queue_Primitive
internal import Queue_Primitives
internal import Storage_Contiguous_Primitives

extension Async.Semaphore {

    @usableFromInline
    enum SignalEffect: ~Copyable, Sendable {

        case none

        case resume(
            Async.Waiter.Resumption,
            skipped: Async.Waiter.Queue.Drain<Async.Waiter.Resumption>
        )

        case skippedOnly(
            Async.Waiter.Queue.Drain<Async.Waiter.Resumption>
        )
    }

    public func signal() {
        let effect: SignalEffect = _state.withLock { state in
            state.metrics.releases += 1
            state.metrics.currentOutstanding -= 1

            var flagged = Async.Waiter.Queue.Drain<
                Async.Waiter.Queue.Flagged<Outcome, Void>
            >()
            let eligible = state.waiters.popEligible(flaggedInto: &flagged)

            let currentLifecycle = state.lifecycle
            var flaggedCount = 0
            var skipped = Async.Waiter.Queue.Drain<Async.Waiter.Resumption>()
            flagged.drain { flaggedEntry in
                flaggedCount += 1

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

                skipped.enqueue(resumption)
            }
            state.metrics.currentWaiters -= flaggedCount

            guard let entry = eligible else {

                state.available += 1
                if skipped.isEmpty {
                    return .none
                }
                return .skippedOnly(skipped)
            }

            state.metrics.currentWaiters -= 1
            state.metrics.acquisitions += 1
            state.metrics.currentOutstanding += 1
            state.metrics.peakOutstanding = max(
                state.metrics.peakOutstanding,
                state.metrics.currentOutstanding
            )
            let resumption = entry.resumption(with: .success(()))
            return .resume(resumption, skipped: skipped)
        }

        switch consume effect {
        case .none:
            return

        case .resume(let resumption, var skipped):
            skipped.drain { $0.resume() }
            resumption.resume()

        case .skippedOnly(var skipped):
            skipped.drain { $0.resume() }
        }
    }
}

extension Async.Semaphore {

    public var metrics: Metrics {
        _state.withLock { $0.metrics }
    }
}
