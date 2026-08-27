#if !hasFeature(Embedded)

    import Queue
    public import Deque
    public import Column
    public import Buffer_Ring_Primitive
    public import Storage_Contiguous
    public import Ownership
    import Memory_Heap
    import Memory_Allocator_Primitive
    import Buffer_Primitive

    extension Async.Channel.Unbounded where Element: ~Copyable {

        @usableFromInline
        struct State: ~Copyable {
            @usableFromInline
            var buffer: Deque<Column.Ring<Element>>

            @usableFromInline
            var waiter: Receive.Continuation?

            @usableFromInline
            var cancelledReceiver: Bool

            @usableFromInline
            var status: Status

            @usableFromInline
            init() {
                self.buffer = Deque()
                self.waiter = nil
                self.cancelledReceiver = false
                self.status = .open
            }
        }
    }

    extension Async.Channel.Unbounded.State where Element: ~Copyable {
        @usableFromInline
        enum Status: Sendable {

            case open

            case closed

            case finished
        }
    }

    extension Async.Channel.Unbounded.State where Element: ~Copyable {
        @usableFromInline
        var isClosed: Bool {
            switch status {
            case .open:
                return false

            case .closed, .finished:
                return true
            }
        }
    }

    extension Async.Channel.Unbounded.State where Element: ~Copyable {
        @usableFromInline
        enum Send {}
    }

    extension Async.Channel.Unbounded.State.Send where Element: ~Copyable {
        @usableFromInline
        enum Action: ~Copyable {
            case give(Async.Channel<Element>.Unbounded.State.Receive.Continuation, Element)
            case keep
            case shut
        }
    }

    extension Async.Channel.Unbounded.State where Element: ~Copyable {

        @usableFromInline
        mutating func send(_ slot: Ownership.Slot<Element>) -> Send.Action {
            switch status {
            case .open:
                if let cont = waiter.take() {
                    let taken = slot.take(__unchecked: ())
                    return .give(cont, taken)
                }
                let taken = slot.take(__unchecked: ())
                buffer.push(taken, to: .back)
                return .keep

            case .closed, .finished:
                return .shut
            }
        }
    }

    extension Async.Channel.Unbounded.State where Element: ~Copyable {
        @usableFromInline
        enum Receive {}
    }

    extension Async.Channel.Unbounded.State.Receive where Element: ~Copyable {

        @usableFromInline
        enum Signal: Sendable {

            case delivered

            case closed

            case cancelled
        }

        @usableFromInline
        typealias Continuation = Async.Continuation<Signal>.Unsafe

        @usableFromInline
        enum Step: ~Copyable {
            case val(
                Element,
                receiver: Async.Channel<Element>.Unbounded.State.Receive.Continuation?
            )
            case end(receiver: Async.Channel<Element>.Unbounded.State.Receive.Continuation?)
            case wait
            case cancelled(receiver: Async.Channel<Element>.Unbounded.State.Receive.Continuation?)
        }

        @usableFromInline
        enum Stop: ~Copyable, Sendable {
            case none
            case stop(Async.Channel<Element>.Unbounded.State.Receive.Continuation)
        }
    }

    extension Async.Channel.Unbounded.State where Element: ~Copyable {

        @usableFromInline
        mutating func poll() -> Element? {
            buffer.take(from: .front)
        }

        @usableFromInline
        mutating func receive() -> Receive.Step {
            if let element = buffer.take(from: .front) {
                return .val(element, receiver: nil)
            }
            if isClosed {
                return .end(receiver: nil)
            }
            return .wait
        }

        @usableFromInline
        mutating func wait(_ cont: consuming Receive.Continuation) -> Receive.Step {
            if cancelledReceiver {
                cancelledReceiver = false
                return .cancelled(receiver: cont)
            }

            precondition(
                waiter == nil,
                "Single-suspended-receiver invariant violated"
            )

            if let element = buffer.take(from: .front) {
                return .val(element, receiver: cont)
            }
            if isClosed {
                return .end(receiver: cont)
            }

            waiter = consume cont
            return .wait
        }

        @usableFromInline
        mutating func stop() -> Receive.Stop {
            if let cont = waiter.take() {
                return .stop(cont)
            }

            cancelledReceiver = true
            return .none
        }
    }

    extension Async.Channel.Unbounded.State where Element: ~Copyable {

        @usableFromInline
        enum Close: ~Copyable, Sendable {
            case none
            case end(Receive.Continuation)
        }

        @usableFromInline
        mutating func close() -> Close {
            guard status == .open else { return .none }

            status = .closed

            guard buffer.isEmpty else { return .none }

            if let cont = waiter.take() {
                return .end(cont)
            }
            return .none
        }
    }

#endif
