#if !hasFeature(Embedded)

    public import Async_Waiter_Primitives
    public import Ownership_Primitives
    internal import Queue_Primitives
    public import Deque_Primitives
    public import Column_Primitives
    public import Buffer_Ring_Primitive
    public import Storage_Contiguous_Primitives
    import Memory_Heap_Primitives
    import Memory_Allocator_Primitive
    import Buffer_Primitive

    extension Async.Channel.Bounded where Element: ~Copyable {

        @usableFromInline
        struct State: ~Copyable {
            @usableFromInline
            var status: Status
            @usableFromInline
            var buffer: Deque<Column.Ring<Element>>
            @usableFromInline
            var senders: Deque<Column.Ring<Sender>>
            @usableFromInline
            var receiver: Receiver?
            @usableFromInline
            let capacity: Index<Element>.Count
            @usableFromInline
            var cancelledReceiver: Bool = false

            @usableFromInline
            init(capacity: Index<Element>.Count) {
                self.status = .open
                self.buffer = Deque()
                self.senders = Deque()
                self.receiver = nil
                self.capacity = capacity
            }
        }
    }

    extension Async.Channel.Bounded.State where Element: ~Copyable {
        @usableFromInline
        enum Status: Sendable {

            case open

            case closed

            case finished
        }
    }

    extension Async.Channel.Bounded.State where Element: ~Copyable {

        @usableFromInline
        struct Sender: ~Copyable, Sendable {
            @usableFromInline
            let slot: Ownership.Slot<Element>
            @usableFromInline
            let continuation: Send.Continuation
            @usableFromInline
            let flag: Async.Waiter.Flag

            @usableFromInline
            init(
                slot: Ownership.Slot<Element>,
                continuation: consuming Send.Continuation,
                flag: Async.Waiter.Flag
            ) {
                self.slot = slot
                self.continuation = continuation
                self.flag = flag
            }
        }
    }

    extension Async.Channel.Bounded.State where Element: ~Copyable {

        @usableFromInline
        struct Receiver: ~Copyable, Sendable {
            @usableFromInline
            let continuation: Receive.Continuation

            @usableFromInline
            init(continuation: consuming Receive.Continuation) {
                self.continuation = continuation
            }
        }
    }

    extension Async.Channel.Bounded.State where Element: ~Copyable {

        @usableFromInline
        mutating func next(
            collectingCancelledInto cancelled: inout Deque<Column.Ring<Send.Continuation>>?
        ) -> Sender? {
            while let sender = senders.take(from: .front) {
                if sender.flag.isFlagged {
                    if cancelled == nil { cancelled = Deque<Column.Ring<Send.Continuation>>() }
                    cancelled?.push(sender.continuation, to: .back)
                    continue
                }
                return sender
            }
            return nil
        }
    }

    extension Async.Channel.Bounded.State where Element: ~Copyable {
        @usableFromInline
        enum Send {}
    }

    extension Async.Channel.Bounded.State.Send where Element: ~Copyable {

        @usableFromInline
        typealias Continuation = Async.Continuation<Async.Channel<Element>.Error?>.Unsafe

        @usableFromInline
        enum Decision: ~Copyable {

            case deliverToReceiver(
                Async.Channel<Element>.Bounded.State.Receive.Continuation,
                Element
            )

            case buffered

            case suspend(flag: Async.Waiter.Flag)

            case rejectClosed
        }

        @usableFromInline
        enum Action: ~Copyable {

            case deliverToReceiver(
                Async.Channel<Element>.Bounded.State.Receive.Continuation,
                Element,
                sender: Async.Channel<Element>.Bounded.State.Send.Continuation
            )

            case buffered(sender: Async.Channel<Element>.Bounded.State.Send.Continuation)

            case suspended

            case rejectClosed(sender: Async.Channel<Element>.Bounded.State.Send.Continuation)

            case rejectCancelled(sender: Async.Channel<Element>.Bounded.State.Send.Continuation)
        }
    }

    extension Async.Channel.Bounded.State where Element: ~Copyable {

        @usableFromInline
        mutating func send(_ slot: Ownership.Slot<Element>) -> Send.Decision {
            switch status {
            case .open:

                if let receiver = self.receiver.take() {
                    let taken = slot.take(__unchecked: ())
                    return .deliverToReceiver(receiver.continuation, taken)
                }

                if buffer.count < capacity {
                    let taken = slot.take(__unchecked: ())
                    buffer.push(taken, to: .back)
                    return .buffered
                }

                return .suspend(flag: Async.Waiter.Flag())

            case .closed, .finished:
                return .rejectClosed
            }
        }

        @usableFromInline
        mutating func suspend(
            flag: Async.Waiter.Flag,
            slot: Ownership.Slot<Element>,
            continuation: consuming Send.Continuation
        ) -> Send.Action {

            if flag.cancelled {
                return .rejectCancelled(sender: continuation)
            }

            switch status {
            case .open:

                if let receiver = self.receiver.take() {
                    let element = slot.take(__unchecked: ())
                    return .deliverToReceiver(receiver.continuation, element, sender: continuation)
                }

                if buffer.count < capacity {
                    buffer.push(slot.take(__unchecked: ()), to: .back)
                    return .buffered(sender: continuation)
                }

                senders.push(Sender(slot: slot, continuation: continuation, flag: flag), to: .back)
                return .suspended

            case .closed, .finished:
                return .rejectClosed(sender: continuation)
            }
        }

        @usableFromInline
        mutating func reap() -> Deque<Column.Ring<Send.Continuation>> {
            var cancelled = Deque<Column.Ring<Send.Continuation>>()
            var survivors = Deque<Column.Ring<Sender>>()
            while let sender = senders.take(from: .front) {
                if sender.flag.isFlagged {
                    cancelled.push(sender.continuation, to: .back)
                } else {
                    survivors.push(sender, to: .back)
                }
            }
            senders = survivors
            return cancelled
        }
    }

    extension Async.Channel.Bounded.State where Element: ~Copyable {
        @usableFromInline
        enum Receive {}
    }

    extension Async.Channel.Bounded.State.Receive where Element: ~Copyable {

        @usableFromInline
        enum Signal: Sendable {

            case delivered

            case closed

            case cancelled
        }

        @usableFromInline
        typealias Continuation = Async.Continuation<Signal>.Unsafe

        @usableFromInline
        enum Action: ~Copyable {

            case returnElement(
                Element,
                resumeSender: Async.Channel<Element>.Bounded.State.Send.Continuation?,
                cancelled: Deque<
                    Column.Ring<Async.Channel<Element>.Bounded.State.Send.Continuation>
                >?,
                receiver: Async.Channel<Element>.Bounded.State.Receive.Continuation?
            )

            case suspend

            case returnNil(receiver: Async.Channel<Element>.Bounded.State.Receive.Continuation?)

            case rejectCancelled(
                receiver: Async.Channel<Element>.Bounded.State.Receive.Continuation?
            )
        }

        @usableFromInline
        enum Cancel: ~Copyable, Sendable {
            case resumeWithCancellation(Async.Channel<Element>.Bounded.State.Receive.Continuation)
            case none
        }
    }

    extension Async.Channel.Bounded.State where Element: ~Copyable {

        @usableFromInline
        mutating func receive() -> Receive.Action {
            switch status {
            case .open:
                precondition(receiver == nil, "Single-consumer invariant violated")

                var cancelled: Deque<Column.Ring<Send.Continuation>>? = nil

                if let element = buffer.take(from: .front) {

                    if let sender = next(collectingCancelledInto: &cancelled) {
                        buffer.push(sender.slot.take(__unchecked: ()), to: .back)
                        return .returnElement(
                            element,
                            resumeSender: sender.continuation,
                            cancelled: cancelled,
                            receiver: nil
                        )
                    }
                    return .returnElement(
                        element,
                        resumeSender: nil,
                        cancelled: cancelled,
                        receiver: nil
                    )
                }

                if let sender = next(collectingCancelledInto: &cancelled) {
                    return .returnElement(
                        sender.slot.take(__unchecked: ()),
                        resumeSender: sender.continuation,
                        cancelled: cancelled,
                        receiver: nil
                    )
                }

                return .suspend

            case .closed:
                if let element = buffer.take(from: .front) {
                    if buffer.isEmpty {
                        status = .finished
                    }
                    return .returnElement(element, resumeSender: nil, cancelled: nil, receiver: nil)
                }
                status = .finished
                return .returnNil(receiver: nil)

            case .finished:
                return .returnNil(receiver: nil)
            }
        }

        @usableFromInline
        mutating func suspend(
            continuation: consuming Receive.Continuation
        ) -> Receive.Action {

            if cancelledReceiver {
                cancelledReceiver = false
                return .rejectCancelled(receiver: continuation)
            }

            switch status {
            case .open:
                precondition(receiver == nil, "Single-consumer invariant violated")

                var cancelled: Deque<Column.Ring<Send.Continuation>>? = nil

                if let element = buffer.take(from: .front) {
                    if let sender = next(collectingCancelledInto: &cancelled) {
                        buffer.push(sender.slot.take(__unchecked: ()), to: .back)
                        return .returnElement(
                            element,
                            resumeSender: sender.continuation,
                            cancelled: cancelled,
                            receiver: continuation
                        )
                    }
                    return .returnElement(
                        element,
                        resumeSender: nil,
                        cancelled: cancelled,
                        receiver: continuation
                    )
                }

                if let sender = next(collectingCancelledInto: &cancelled) {
                    return .returnElement(
                        sender.slot.take(__unchecked: ()),
                        resumeSender: sender.continuation,
                        cancelled: cancelled,
                        receiver: continuation
                    )
                }

                receiver = Receiver(continuation: continuation)
                return .suspend

            case .closed:
                if let element = buffer.take(from: .front) {
                    if buffer.isEmpty {
                        status = .finished
                    }
                    return .returnElement(
                        element,
                        resumeSender: nil,
                        cancelled: nil,
                        receiver: continuation
                    )
                }
                status = .finished
                return .returnNil(receiver: continuation)

            case .finished:
                return .returnNil(receiver: continuation)
            }
        }

        @usableFromInline
        mutating func cancel() -> Receive.Cancel {
            switch status {
            case .open:
                if let receiver = self.receiver.take() {
                    return .resumeWithCancellation(receiver.continuation)
                }

                cancelledReceiver = true
                return .none

            case .closed, .finished:
                return .none
            }
        }
    }

    extension Async.Channel.Bounded.State where Element: ~Copyable {
        @usableFromInline
        struct Close: ~Copyable, Sendable {

            @usableFromInline
            var receiverToResume: Receive.Continuation?
            @usableFromInline
            var sendersToCancel: Deque<Column.Ring<Send.Continuation>>

            @usableFromInline
            init(
                receiverToResume: consuming Receive.Continuation?,
                sendersToCancel: consuming Deque<Column.Ring<Send.Continuation>>
            ) {
                self.receiverToResume = receiverToResume
                self.sendersToCancel = sendersToCancel
            }
        }

        @usableFromInline
        mutating func close() -> Close {
            switch status {
            case .open:

                var sendersToCancel = Deque<Column.Ring<Send.Continuation>>()
                while let sender = senders.take(from: .front) {
                    sendersToCancel.push(sender.continuation, to: .back)
                }

                if buffer.isEmpty {
                    if let receiver = self.receiver.take() {
                        status = .finished
                        return Close(
                            receiverToResume: receiver.continuation,
                            sendersToCancel: sendersToCancel
                        )
                    }
                    status = .finished
                } else {
                    status = .closed
                }
                return Close(receiverToResume: nil, sendersToCancel: sendersToCancel)

            case .closed, .finished:
                return Close(
                    receiverToResume: nil,
                    sendersToCancel: Deque<Column.Ring<Send.Continuation>>()
                )
            }
        }
    }

    extension Async.Channel.Bounded.State where Element: ~Copyable {
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

#endif
