public import Async_Lifecycle
public import Async_Primitive
public import Async_Waiter
internal import Buffer_Ring_Primitive
internal import Memory_Allocator_Primitive
internal import Memory
public import Queue_Primitive
internal import Storage_Contiguous

extension Async.Semaphore {

    @usableFromInline
    package struct State: ~Copyable {

        @usableFromInline
        let capacity: Int

        @usableFromInline
        var available: Int

        @usableFromInline
        var waiters: Async.Waiter.Queue.Unbounded<Outcome, Void>

        @usableFromInline
        var lifecycle: Async.Lifecycle.State

        @usableFromInline
        var metrics: Async.Semaphore.Metrics

        @usableFromInline
        init(capacity: Int) {
            self.capacity = capacity
            self.available = capacity
            self.waiters = Async.Waiter.Queue.Unbounded()
            self.lifecycle = .open
            self.metrics = Metrics()
        }
    }
}

extension Async.Semaphore {

    @usableFromInline
    typealias Outcome = Result<Void, Async.Semaphore.Error>
}
