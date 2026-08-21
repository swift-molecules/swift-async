#if !hasFeature(Embedded)

    import Dictionary_Primitives
    import Dictionary_Ordered_Primitives
    import Hash_Indexed_Primitive
    import Hash_Primitives
    import Queue_Primitives
    import Deque_Primitives
    import Column_Primitives
    import Buffer_Ring_Primitive
    import Buffer_Linear_Primitive
    import Storage_Contiguous_Primitives
    import Memory_Heap_Primitives
    import Memory_Allocator_Primitive
    import Buffer_Primitive

    extension Async.Broadcast {

        struct State: ~Copyable {

            var buffer: Deque<Column.Ring<(index: UInt64, element: Element)>> = .init()

            var next: Next.Index = .init()

            var subscribers: Dictionary<UInt64, Subscriber>.Ordered = .init()

            var subscriber: Subscriber.ID = .init()

            var `is`: Is = .active
        }

    }

    extension Async.Broadcast.State {

        mutating func cancel(
            subscriber subscriberID: UInt64,
            token: UInt64
        ) -> CheckedContinuation<Async.Broadcast<Element>.Next.Outcome, Never>? {
            let cleared = subscribers.withMutableValue(forKey: subscriberID) {
                subscriber -> CheckedContinuation<Async.Broadcast<Element>.Next.Outcome, Never>? in

                guard subscriber.wait.token == token,
                    let cont = subscriber.continuation
                else { return nil }

                subscriber.continuation = nil

                return cont
            }

            return cleared ?? nil
        }
    }

#endif
