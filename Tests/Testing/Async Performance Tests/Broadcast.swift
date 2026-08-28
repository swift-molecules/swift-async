import Async
import Testing

extension Benchmark {
    @Suite struct Broadcast {}
}

extension Benchmark.Broadcast {

    @Test(.timed(iterations: 10, warmup: 2))
    func `1000 sends to 50 subscribers`() async throws {
        let broadcast = Async.Broadcast<Int>(bufferCapacity: Benchmark.iterations)
        let subscriptions = (0..<50).map { _ in broadcast.subscribe() }

        for i in 0..<Benchmark.iterations {
            broadcast.send(i)
        }
        broadcast.finish()

        for sub in subscriptions {
            var count = 0
            for try await _ in sub { count += 1 }
            #expect(count == Benchmark.iterations)
        }
    }

    @Test(.timed(iterations: 10, warmup: 2))
    func `1000 sends to 3 subscribers`() async throws {
        let broadcast = Async.Broadcast<Int>(bufferCapacity: Benchmark.iterations)
        let subscriptions = (0..<3).map { _ in broadcast.subscribe() }

        for i in 0..<Benchmark.iterations {
            broadcast.send(i)
        }
        broadcast.finish()

        for sub in subscriptions {
            var count = 0
            for try await _ in sub { count += 1 }
            #expect(count == Benchmark.iterations)
        }
    }
}

extension Benchmark.Broadcast {

    @Test(.timed(iterations: 10, warmup: 2))
    func `1000 buffered iterations`() async throws {
        let broadcast = Async.Broadcast<Int>(bufferCapacity: Benchmark.iterations)
        let subscription = broadcast.subscribe()

        for i in 0..<Benchmark.iterations {
            broadcast.send(i)
        }
        broadcast.finish()

        var count = 0
        for try await _ in subscription { count += 1 }
        #expect(count == Benchmark.iterations)
    }
}

extension Benchmark.Broadcast {

    @Test(.timed(iterations: 10, warmup: 2))
    func `1000 round-trips with 10 subscribers`() async throws {
        let broadcast = Async.Broadcast<Int>(bufferCapacity: Benchmark.iterations)
        let subscriptions = (0..<10).map { _ in broadcast.subscribe() }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for i in 0..<Benchmark.iterations {
                    broadcast.send(i)
                }
                broadcast.finish()
            }

            for sub in subscriptions {
                group.addTask {
                    var count = 0
                    for try await _ in sub { count += 1 }
                    #expect(count == Benchmark.iterations)
                }
            }

            try await group.waitForAll()
        }
    }
}
