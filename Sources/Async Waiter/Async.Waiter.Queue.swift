import Buffer_Primitive
public import Buffer_Ring_Bounded_Primitive
import Buffer_Ring_Primitive
import Column
import Memory_Allocator_Primitive
import Memory_Heap
public import Queue
public import Storage_Contiguous

extension Async.Waiter {

    public enum Queue {}
}

extension Async.Waiter.Queue {

    public typealias Bounded<Outcome: Sendable, Metadata: ~Copyable & Sendable> =
        Queue.Queue<Async.Waiter.Entry<Outcome, Metadata>>.Bounded

    public typealias Unbounded<Outcome: Sendable, Metadata: ~Copyable & Sendable> =
        Queue.Queue<Async.Waiter.Entry<Outcome, Metadata>>

    public typealias Drain<Element: ~Copyable> = Queue.Queue<Element>
}
