internal import Async_Mutex
public import Async_Primitive
internal import Async_Promise
internal import Async_Waiter
internal import Buffer_Ring_Primitive
internal import Memory_Allocator_Primitive
internal import Memory
internal import Queue_Primitive
internal import Queue
internal import Storage_Contiguous

extension Async.Semaphore {

    public func shutdown() {
        let resumptions: Async.Waiter.Queue.Drain<Async.Waiter.Resumption> = _state.withLock {
            state in

            guard state.lifecycle.shutdown.begin() else {
                return Async.Waiter.Queue.Drain<Async.Waiter.Resumption>()
            }

            var pending = Async.Waiter.Queue.Drain<Async.Waiter.Resumption>()
            state.waiters.drain { entry in
                pending.enqueue(entry.resumption(with: .failure(.shutdown)))
            }
            state.metrics.currentWaiters = 0

            _ = state.lifecycle.shutdown.complete()

            return pending
        }

        var toResume = resumptions
        toResume.drain { $0.resume() }

        _ = _shutdownGate.open()
    }

    public var isShutdown: Bool {
        _state.withLock { !$0.lifecycle.isOpen }
    }
}
