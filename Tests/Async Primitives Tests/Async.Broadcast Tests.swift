#if canImport(Async_Broadcast_Primitives)

    import Async_Primitives_Test_Support
    import Testing

    @Suite
    struct BroadcastTests {

        @Test
        func `Single subscriber receives all elements`() async throws {
            let broadcast = Async.Broadcast<Int>()
            let subscription = broadcast.subscribe()

            broadcast.send(1)
            broadcast.send(2)
            broadcast.send(3)
            broadcast.finish()

            var received: [Int] = []
            for try await value in subscription {
                received.append(value)
            }

            #expect(received == [1, 2, 3])
        }

        @Test
        func `Multiple subscribers each receive all elements`() async throws {
            let broadcast = Async.Broadcast<Int>()
            let sub1 = broadcast.subscribe()
            let sub2 = broadcast.subscribe()

            broadcast.send(1)
            broadcast.send(2)
            broadcast.finish()

            let task1 = Task {
                var received: [Int] = []
                for try await value in sub1 {
                    received.append(value)
                }
                return received
            }

            let task2 = Task {
                var received: [Int] = []
                for try await value in sub2 {
                    received.append(value)
                }
                return received
            }

            let result1 = try await task1.value
            let result2 = try await task2.value

            #expect(result1 == [1, 2])
            #expect(result2 == [1, 2])
        }

        @Test
        func `Late subscriber only sees new elements`() async throws {
            let broadcast = Async.Broadcast<Int>()

            broadcast.send(1)

            let subscription = broadcast.subscribe()

            broadcast.send(2)
            broadcast.send(3)
            broadcast.finish()

            var received: [Int] = []
            for try await value in subscription {
                received.append(value)
            }

            #expect(received == [2, 3])
        }

        @Test
        func `isFinished reflects state`() {
            let broadcast = Async.Broadcast<Int>()
            #expect(broadcast.isFinished == false)
            broadcast.finish()
            #expect(broadcast.isFinished == true)
        }

        @Test
        func `Subscriber suspends until element available`() async throws {
            let broadcast = Async.Broadcast<Int>()
            let subscription = broadcast.subscribe()
            let started = Async.Barrier(parties: 2)

            let receiveTask = Task { () -> Int? in
                try? await started.arrive()
                var iterator = subscription.makeAsyncIterator()
                return try await iterator.next()
            }

            try? await started.arrive()

            broadcast.send(42)

            let result = try await receiveTask.value
            #expect(result == 42)
        }

        @Test
        func `Subscriber resumes with nil on finish`() async throws {
            let broadcast = Async.Broadcast<Int>()
            let subscription = broadcast.subscribe()
            let started = Async.Barrier(parties: 2)

            let receiveTask = Task { () -> Int? in
                try? await started.arrive()
                var iterator = subscription.makeAsyncIterator()
                return try await iterator.next()
            }

            try? await started.arrive()

            broadcast.finish()

            let result = try await receiveTask.value
            #expect(result == nil)
        }

        @Test
        func `Cancel subscription stops iteration`() async throws {
            let broadcast = Async.Broadcast<Int>()
            let subscription = broadcast.subscribe()
            let started = Async.Barrier(parties: 2)

            let receiveTask = Task { () -> Int? in
                try? await started.arrive()
                var iterator = subscription.makeAsyncIterator()
                return try await iterator.next()
            }

            try? await started.arrive()

            subscription.cancel()

            let result = try await receiveTask.value
            #expect(result == nil)
        }

        @Test
        func `Elements delivered in order`() async throws {

            let broadcast = Async.Broadcast<Int>(bufferCapacity: 100)
            let subscription = broadcast.subscribe()

            (1...100).forEach { i in
                broadcast.send(i)
            }
            broadcast.finish()

            var received: [Int] = []
            for try await value in subscription {
                received.append(value)
            }

            #expect(received == Array(1...100))
        }

        @Test
        func `Send after finish is ignored`() async throws {
            let broadcast = Async.Broadcast<Int>()
            let subscription = broadcast.subscribe()

            broadcast.send(1)
            broadcast.finish()
            broadcast.send(2)

            var received: [Int] = []
            for try await value in subscription {
                received.append(value)
            }

            #expect(received == [1])
        }

        @Test
        func `Task cancellation throws cancelled error`() async {
            let broadcast = Async.Broadcast<Int>()
            let subscription = broadcast.subscribe()
            let started = Async.Barrier(parties: 2)

            let receiveTask = Task {
                try? await started.arrive()
                var iterator = subscription.makeAsyncIterator()
                return try await iterator.next()
            }

            try? await started.arrive()

            receiveTask.cancel()

            do {
                _ = try await receiveTask.value
                Issue.record("Expected cancellation error")
            } catch let error as Async.Broadcast<Int>.Error {
                #expect(error == .cancelled)
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    @Suite
    struct BroadcastStressTests {

        private func yieldProgress(iterations: Int = 50) async {
            for _ in 0..<iterations {
                await Task.yield()
            }
        }

        @Test
        func `All subscribers receive all elements - no loss`() async throws {

            for round in 0..<20 {
                let elementCount = 50

                let broadcast = Async.Broadcast<Int>(bufferCapacity: elementCount)
                let subscriberCount = 5

                let subscriptions = (0..<subscriberCount).map { _ in
                    broadcast.subscribe()
                }

                let consumerTasks = subscriptions.map { subscription in
                    Task {
                        var received: [Int] = []
                        for try await value in subscription {
                            received.append(value)
                        }
                        return received
                    }
                }

                await yieldProgress(iterations: 20)

                (0..<elementCount).forEach { i in
                    broadcast.send(i)
                }
                broadcast.finish()

                for (index, task) in consumerTasks.enumerated() {
                    let received = try await task.value

                    #expect(
                        received.count == elementCount,
                        "Round \(round), subscriber \(index): count \(received.count) != \(elementCount)"
                    )
                    #expect(
                        received == Array(0..<elementCount),
                        "Round \(round), subscriber \(index): elements mismatch"
                    )
                }
            }
        }

        @Test
        func `Cancellation racing with send - token matching correctness`() async throws {

            for round in 0..<30 {
                let elementCount = 20
                let broadcast = Async.Broadcast<Int>(bufferCapacity: elementCount)
                let subscriberCount = 10

                let subscriptions = (0..<subscriberCount).map { _ in
                    broadcast.subscribe()
                }

                let consumerTasks = subscriptions.enumerated().map { index, subscription in
                    Task {
                        var received: [Int] = []
                        var iterator = subscription.makeAsyncIterator()
                        while true {
                            do {
                                guard let value = try await iterator.next() else {
                                    break
                                }
                                received.append(value)
                            } catch let error as Async.Broadcast<Int>.Error {
                                #expect(
                                    error == .cancelled,
                                    "Round \(round), subscriber \(index): Expected .cancelled, got \(error)"
                                )
                                return (index, received, true)
                            } catch {
                                #expect(
                                    Bool(false),
                                    "Round \(round), subscriber \(index): Unexpected error: \(error)"
                                )
                                break
                            }
                        }
                        return (index, received, false)
                    }
                }

                broadcast.send(0)
                await yieldProgress(iterations: 30)

                for i in stride(from: 0, to: subscriberCount, by: 2) {
                    consumerTasks[i].cancel()
                }

                for i in 1..<elementCount {
                    broadcast.send(i)
                    await Task.yield()
                }
                broadcast.finish()

                var cancelledCount = 0
                for task in consumerTasks {
                    let (index, received, wasCancelled) = await task.value

                    if wasCancelled {
                        cancelledCount += 1

                        #expect(
                            received.first == 0 || received.isEmpty,
                            "Round \(round), cancelled subscriber \(index): Unexpected first element"
                        )
                    } else {

                        #expect(
                            received == Array(0..<elementCount),
                            "Round \(round), subscriber \(index): Expected all elements"
                        )
                    }
                }

                #expect(cancelledCount > 0, "Round \(round): No cancellations observed")
            }
        }

        @Test
        func `Finish racing with pending subscribers - all resume with nil`() async throws {

            for round in 0..<30 {
                let broadcast = Async.Broadcast<Int>()
                let subscriberCount = 15
                let preBufferedCount = 5

                (0..<preBufferedCount).forEach { i in
                    broadcast.send(i)
                }

                let subscriptions = (0..<subscriberCount).map { _ in
                    broadcast.subscribe()
                }

                let consumerTasks = subscriptions.map { subscription in
                    Task { () -> [Int] in
                        var received: [Int] = []
                        for try await value in subscription {
                            received.append(value)
                        }
                        return received
                    }
                }

                await yieldProgress()

                broadcast.finish()

                for (index, task) in consumerTasks.enumerated() {
                    let received = try await task.value

                    #expect(
                        received.isEmpty,
                        "Round \(round), subscriber \(index): Expected empty, got \(received.count) elements"
                    )
                }
            }
        }

        @Test
        func `Many subscribers with interleaved send and cancel`() async throws {

            let subscriberCount = 20
            let elementCount = 500
            let broadcast = Async.Broadcast<Int>(bufferCapacity: elementCount)

            let results = Async.Channel<(id: Int, elements: [Int], terminatedViaCancellation: Bool)>
                .Unbounded().take().ends()
            let ready = Async.Channel<Int>.Unbounded().take().ends()

            var subscriberTasks: [(id: Int, task: Task<Void, Never>)] = []

            for id in 0..<subscriberCount {
                let task = Task { [sender = results.sender] in
                    let subscription = broadcast.subscribe()
                    var received: [Int] = []
                    var terminatedViaCancellation = false

                    var iterator = subscription.makeAsyncIterator()
                    do {
                        try ready.sender.send(id)
                    } catch { #expect(Bool(false), "ready channel unexpectedly closed") }

                    loop: while true {
                        do {
                            guard let value = try await iterator.next() else {
                                break loop
                            }
                            received.append(value)
                            await Task.yield()
                        } catch let error as Async.Broadcast<Int>.Error {

                            #expect(
                                error == .cancelled,
                                "Subscriber \(id): Unexpected broadcast error: \(error)"
                            )
                            terminatedViaCancellation = true
                            break loop
                        } catch {

                            #expect(
                                Bool(false),
                                "Subscriber \(id): Unexpected error type: \(error)"
                            )
                            break loop
                        }
                    }

                    do {
                        try sender.send(
                            (
                                id: id, elements: received,
                                terminatedViaCancellation: terminatedViaCancellation
                            )
                        )
                    } catch { #expect(Bool(false), "results channel unexpectedly closed") }
                }
                subscriberTasks.append((id: id, task: task))
            }

            let idsToCancel = Set(stride(from: 0, to: subscriberCount, by: 3))
            let controlSubscriberID = 0

            for _ in 0..<subscriberCount {
                _ = try await ready.receiver.receive()
            }
            ready.close()

            let controlTask = subscriberTasks[controlSubscriberID].task
            controlTask.cancel()
            await controlTask.value

            await withTaskGroup(of: Void.self) { group in

                group.addTask {
                    for i in 0..<elementCount {
                        broadcast.send(i)
                        if i % 20 == 0 { await Task.yield() }
                    }
                    broadcast.finish()
                }

                group.addTask { [subscriberTasks] in
                    for _ in 0..<10 { await Task.yield() }
                    for entry in subscriberTasks where
                        idsToCancel.contains(entry.id) && entry.id != controlSubscriberID
                    {
                        entry.task.cancel()
                    }
                }

                group.addTask { [subscriberTasks] in
                    for entry in subscriberTasks {
                        await entry.task.value
                    }
                }
            }

            results.close()

            var completedSubscribers = 0
            var cancelledSubscribers = 0

            while let result = try await results.receiver.receive() {
                completedSubscribers += 1

                for (previous, next) in zip(result.elements, result.elements.dropFirst()) {
                    #expect(
                        next > previous,
                        "Subscriber \(result.id): Out of order: \(previous) -> \(next)"
                    )
                }

                #expect(
                    Set(result.elements).count == result.elements.count,
                    "Subscriber \(result.id): Duplicate elements detected"
                )

                for value in result.elements {
                    #expect(
                        (0..<elementCount).contains(value),
                        "Subscriber \(result.id): Value \(value) out of range [0, \(elementCount))"
                    )
                }

                if result.terminatedViaCancellation {
                    cancelledSubscribers += 1
                    #expect(
                        idsToCancel.contains(result.id),
                        "Subscriber \(result.id): Unexpected cancellation"
                    )
                } else {
                    #expect(
                        result.elements == Array(0..<elementCount),
                        "Subscriber \(result.id): A non-cancelled subscriber must receive every element"
                    )
                }

                if result.id == controlSubscriberID {
                    #expect(result.terminatedViaCancellation)
                    #expect(result.elements.isEmpty)
                }
            }

            #expect(
                completedSubscribers == subscriberCount,
                "Expected \(subscriberCount) subscribers to terminate, got \(completedSubscribers)"
            )
            #expect(cancelledSubscribers > 0, "Expected at least one subscriber cancellation")
        }

        @Test
        func `Buffer trimming with slow subscriber`() async throws {

            let bufferCapacity = 20
            let broadcast = Async.Broadcast<Int>(bufferCapacity: bufferCapacity)
            let elementCount = 100

            let fastSub = broadcast.subscribe()
            let slowSub = broadcast.subscribe()

            let fastTask = Task {
                var received: [Int] = []
                for try await value in fastSub {
                    received.append(value)
                }
                return received
            }

            let slowTask = Task {
                var received: [Int] = []
                var iterator = slowSub.makeAsyncIterator()
                while let value = try await iterator.next() {
                    received.append(value)

                    for _ in 0..<10 {
                        await Task.yield()
                    }
                }
                return received
            }

            Task {
                for i in 0..<elementCount {
                    broadcast.send(i)
                    await Task.yield()
                }
                broadcast.finish()
            }

            let fastReceived = try await fastTask.value
            let slowReceived = try await slowTask.value

            #expect(
                fastReceived == Array(0..<elementCount),
                "Fast subscriber should receive all elements in order"
            )

            (1..<slowReceived.count).forEach { i in
                #expect(
                    slowReceived[i] > slowReceived[i - 1],
                    "Slow subscriber elements out of order at index \(i)"
                )
            }

            #expect(
                Set(slowReceived).count == slowReceived.count,
                "Slow subscriber has duplicates"
            )

            for value in slowReceived {
                #expect(
                    (0..<elementCount).contains(value),
                    "Slow subscriber received out-of-range value: \(value)"
                )
            }
        }

        @Test
        func `Sequential next usage is correct`() async throws {

            let broadcast = Async.Broadcast<Int>()
            let subscription = broadcast.subscribe()

            (0..<10).forEach { i in
                broadcast.send(i)
            }
            broadcast.finish()

            var received: [Int] = []
            for try await value in subscription {
                received.append(value)
            }

            #expect(received == Array(0..<10))
        }
    }

    @Suite("Broadcast")
    struct Tests {
        @Test
        func
            `send trims the replay buffer to bufferLimit behind a stalled subscriber, which observes loss`()
            async throws
        {

            let bufferLimit = 4
            let broadcast = Async.Broadcast<Int>(bufferCapacity: bufferLimit)

            let stalled = broadcast.subscribe()

            let elementCount = 50
            (0..<elementCount).forEach { i in
                broadcast.send(i)
            }
            broadcast.finish()

            var received: [Int] = []
            for try await value in stalled {
                received.append(value)
            }

            #expect(received == Array((elementCount - bufferLimit)..<elementCount))
        }

        @Test
        func
            `Loss fires with a positive dropped count when a lagging subscriber's cursor is advanced past drops`()
            async throws
        {
            let bufferLimit = 4
            let recorder = LossRecorder()
            let broadcast = Async.Broadcast<Int>(bufferCapacity: bufferLimit) { loss in
                recorder.record(loss)
            }

            let stalled = broadcast.subscribe()

            let elementCount = 50
            (0..<elementCount).forEach { i in
                broadcast.send(i)
            }
            broadcast.finish()

            var received: [Int] = []
            for try await value in stalled {
                received.append(value)
            }

            #expect(received == Array((elementCount - bufferLimit)..<elementCount))

            let losses = recorder.events

            #expect(!losses.isEmpty, "Expected at least one Loss signal for the stalled subscriber")
            for loss in losses {
                #expect(
                    loss.droppedCount > 0,
                    "droppedCount must be positive — this signal only fires on genuine lag"
                )
                #expect(loss.reason == .capacityLimit)
            }

            #expect(losses.last?.resumingAtIndex == UInt64(elementCount - bufferLimit))

            #expect(Set(losses.map(\.subscriberID)).count == 1)

            #expect(losses.reduce(0) { $0 + $1.droppedCount } >= elementCount - bufferLimit)
        }

        @Test
        func `Loss does not fire when no subscriber lags`() async throws {
            let recorder = LossRecorder()

            let broadcast = Async.Broadcast<Int>(bufferCapacity: 100) { loss in
                recorder.record(loss)
            }
            let subscription = broadcast.subscribe()

            (0..<10).forEach { i in
                broadcast.send(i)
            }
            broadcast.finish()

            var received: [Int] = []
            for try await value in subscription {
                received.append(value)
            }

            #expect(received == Array(0..<10))
            #expect(
                recorder.events.isEmpty,
                "No subscriber lagged behind the (never-trimmed) buffer; Loss must not fire"
            )
        }

        @Test
        func
            `Loss does not fire for a subscriber that joins late, since replay from the current window is not loss`()
            async throws
        {
            let bufferLimit = 4
            let recorder = LossRecorder()
            let broadcast = Async.Broadcast<Int>(bufferCapacity: bufferLimit) { loss in
                recorder.record(loss)
            }

            (0..<20).forEach { i in
                broadcast.send(i)
            }

            #expect(recorder.events.isEmpty)

            let lateSubscriber = broadcast.subscribe()

            (20..<24).forEach { i in
                broadcast.send(i)
            }
            broadcast.finish()

            var received: [Int] = []
            for try await value in lateSubscriber {
                received.append(value)
            }

            #expect(received == Array(20..<24))
            #expect(
                recorder.events.isEmpty,
                "A subscriber that joins after a drop must never be reported as lagging — its cursor starts at the current window"
            )
        }

        @Test
        func `Loss accounts for multiple lagging subscribers individually`() async throws {
            let bufferLimit = 4
            let recorder = LossRecorder()
            let broadcast = Async.Broadcast<Int>(bufferCapacity: bufferLimit) { loss in
                recorder.record(loss)
            }

            let stalledA = broadcast.subscribe()
            let stalledB = broadcast.subscribe()

            let elementCount = 30
            (0..<elementCount).forEach { i in
                broadcast.send(i)
            }
            broadcast.finish()

            var receivedA: [Int] = []
            for try await value in stalledA { receivedA.append(value) }
            var receivedB: [Int] = []
            for try await value in stalledB { receivedB.append(value) }

            #expect(receivedA == Array((elementCount - bufferLimit)..<elementCount))
            #expect(receivedB == Array((elementCount - bufferLimit)..<elementCount))

            let losses = recorder.events
            let subscriberIDs = Set(losses.map(\.subscriberID))

            #expect(
                subscriberIDs.count == 2,
                "Expected loss events for exactly 2 distinct lagging subscribers, got \(subscriberIDs)"
            )
            for id in subscriberIDs {
                let idLosses = losses.filter { $0.subscriberID == id }
                #expect(!idLosses.isEmpty)
                for loss in idLosses {
                    #expect(loss.droppedCount > 0)
                    #expect(loss.reason == .capacityLimit)
                }
            }
        }

        @Test
        func
            `Broadcast without an onLoss handler behaves exactly as before, and Loss.Reason equality holds`()
            async throws
        {

            let bufferLimit = 4
            let broadcast = Async.Broadcast<Int>(bufferCapacity: bufferLimit)
            let stalled = broadcast.subscribe()

            let elementCount = 20
            (0..<elementCount).forEach { i in
                broadcast.send(i)
            }
            broadcast.finish()

            var received: [Int] = []
            for try await value in stalled { received.append(value) }

            #expect(received == Array((elementCount - bufferLimit)..<elementCount))

            #expect(Async.Broadcast<Int>.Loss.Reason.capacityLimit == .capacityLimit)
        }
    }

    private final class LossRecorder: @unchecked Sendable {
        private(set) var events: [Async.Broadcast<Int>.Loss] = []

        func record(_ event: Async.Broadcast<Int>.Loss) {
            events.append(event)
        }
    }

#endif
