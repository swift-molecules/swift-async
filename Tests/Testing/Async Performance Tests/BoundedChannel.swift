import Async
import Async_Test_Support
import Testing

extension Benchmark {
    @Suite struct BoundedChannel {}
}

extension Benchmark.BoundedChannel {

    @Test(.timed(iterations: 10, warmup: 2))
    func `1000 round-trips capacity 1`() async throws {
        let channel = Async.Channel<Int>.Bounded(capacity: 1)
        let sender = channel.sender

        let producer = Task.detached {
            for i in 0..<Benchmark.iterations {
                try await sender.send(i)
            }
        }

        for _ in 0..<Benchmark.iterations {
            _ = try await channel.receiver.receive()
        }

        _ = try await producer.value
    }

    @Test(.timed(iterations: 10, warmup: 2))
    func `1000 round-trips capacity 1000`() async throws {
        let channel = Async.Channel<Int>.Bounded(capacity: 1_000)
        let sender = channel.sender

        let producer = Task.detached {
            for i in 0..<Benchmark.iterations {
                try await sender.send(i)
            }
        }

        for _ in 0..<Benchmark.iterations {
            _ = try await channel.receiver.receive()
        }

        _ = try await producer.value
    }

    @Test(.timed(iterations: 10, warmup: 2))
    func `1000 immediate sends capacity 1000`() async throws {
        let channel = Async.Channel<Int>.Bounded(capacity: 1_000)
        let sender = channel.sender

        let producer = Task.detached {
            for i in 0..<Benchmark.iterations {
                try sender.send.immediate(i)
            }
        }

        for _ in 0..<Benchmark.iterations {
            _ = try await channel.receiver.receive()
        }

        _ = try await producer.value
    }
}
