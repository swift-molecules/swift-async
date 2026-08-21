import Buffer_Primitive
public import Buffer_Ring_Bounded_Primitive
import Buffer_Ring_Primitive
import Column_Primitives
import Memory_Allocator_Primitive
import Memory_Heap_Primitives
public import Queue_Primitives
public import Storage_Contiguous_Primitives

extension Async.Waiter {

    public enum Queue {}
}

extension Async.Waiter.Queue {

    public typealias Bounded<Outcome: Sendable, Metadata: ~Copyable & Sendable> =
        Queue_Primitives.Queue<Async.Waiter.Entry<Outcome, Metadata>>.Bounded

    public typealias Unbounded<Outcome: Sendable, Metadata: ~Copyable & Sendable> =
        Queue_Primitives.Queue<Async.Waiter.Entry<Outcome, Metadata>>

    public typealias Drain<Element: ~Copyable> = Queue_Primitives.Queue<Element>
}
