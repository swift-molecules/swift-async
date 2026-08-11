// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-async open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-async project authors
// Licensed under Apache License v2.0
//
// ===----------------------------------------------------------------------===//

import Async_Primitives_Test_Support
import Testing

@Suite
struct `TypedChannel` {
    enum Failure: Swift.Error, Sendable, Equatable {
        case stopped(Int)
    }

    @Test
    func `sender sends and finishes receiver`() async throws {
        var channel = Async.Channel<Int>.Typed<Failure>.Bounded(capacity: 1)

        try await channel.sender.send(42)
        channel.sender.finish()

        #expect(try await channel.receiver.receive() == 42)
        #expect(try await channel.receiver.receive() == nil)
    }

    @Test
    func `sender failure preserves buffered drain and identity`() async throws {
        var channel = Async.Channel<Int>.Typed<Failure>.Bounded(capacity: 2)

        try await channel.sender.send(1)
        channel.sender.fail(.stopped(2))

        #expect(try await channel.receiver.receive() == 1)
        do throws(Async.Channel<Int>.Typed<Failure>.Error) {
            _ = try await channel.receiver.receive()
            Issue.record("Expected sender failure after the buffered drain")
        } catch {
            switch error {
            case .failed(.stopped(2)):
                break
            default:
                Issue.record("Expected the sender's declared failure")
            }
        }
    }

    @Test
    func `receiver failure propagates to sender`() async {
        var channel = Async.Channel<Int>.Typed<Failure>.Bounded(capacity: 1)

        channel.receiver.fail(.stopped(3))

        do throws(Async.Channel<Int>.Typed<Failure>.Error) {
            try await channel.sender.send(1)
            Issue.record("Expected receiver failure to reject the sender")
        } catch {
            switch error {
            case .failed(.stopped(3)):
                break
            default:
                Issue.record("Expected the receiver's declared failure")
            }
        }
    }

    @Test
    func `first terminal operation wins`() async throws {
        var channel = Async.Channel<Int>.Typed<Failure>.Bounded(capacity: 1)

        channel.sender.fail(.stopped(4))
        channel.sender.finish()

        do throws(Async.Channel<Int>.Typed<Failure>.Error) {
            _ = try await channel.receiver.receive()
            Issue.record("Expected the first terminal failure")
        } catch {
            switch error {
            case .failed(.stopped(4)):
                break
            default:
                Issue.record("Expected the first terminal operation to win")
            }
        }
    }

    @Test
    func `typed sender retains bounded backpressure`() async throws {
        var channel = Async.Channel<Int>.Typed<Failure>.Bounded(capacity: 1)
        let sender = channel.sender
        let gate = Async.Barrier(parties: 2)

        try await sender.send(1)
        let blocked = Task {
            try? await gate.arrive()
            try await sender.send(2)
        }

        try? await gate.arrive()
        #expect(try await channel.receiver.receive() == 1)
        try await blocked.value
        #expect(try await channel.receiver.receive() == 2)
    }

    @Test
    func `receiver failure resumes a backpressured sender with the same failure`() async throws {
        var channel = Async.Channel<Int>.Typed<Failure>.Bounded(capacity: 1)
        let sender = channel.sender
        let gate = Async.Barrier(parties: 2)

        try await sender.send(1)
        let blocked = Task { () -> Async.Channel<Int>.Typed<Failure>.Error? in
            try? await gate.arrive()
            do throws(Async.Channel<Int>.Typed<Failure>.Error) {
                try await sender.send(2)
                return nil
            } catch {
                return error
            }
        }

        try? await gate.arrive()
        channel.receiver.fail(.stopped(5))

        let result = await blocked.value
        switch result {
        case .some(.failed(.stopped(5))):
            break
        default:
            Issue.record("Expected receiver failure to resume the blocked sender")
        }
    }

    @Test
    func `cancelling a backpressured sender preserves cancellation`() async throws {
        var channel = Async.Channel<Int>.Typed<Failure>.Bounded(capacity: 1)
        let sender = channel.sender
        let gate = Async.Barrier(parties: 2)

        try await sender.send(1)
        let blocked = Task { () -> Async.Channel<Int>.Typed<Failure>.Error? in
            try? await gate.arrive()
            do throws(Async.Channel<Int>.Typed<Failure>.Error) {
                try await sender.send(2)
                return nil
            } catch {
                return error
            }
        }

        try? await gate.arrive()
        blocked.cancel()

        let result = await blocked.value
        switch result {
        case .some(.cancelled):
            break
        default:
            Issue.record("Expected cancellation to remain distinct from terminal failure")
        }
    }

    @Test
    func `duplex half close drains before the peer sees completion`() async throws {
        var (left, right) = Async.Channel<Int>.Duplex<Failure>.pair(capacity: 1)

        try await left.outbound.send(1)
        left.outbound.finish()

        #expect(try await right.inbound.receive() == 1)
        #expect(try await right.inbound.receive() == nil)

        try await right.outbound.send(2)
        right.outbound.finish()

        #expect(try await left.inbound.receive() == 2)
        #expect(try await left.inbound.receive() == nil)
    }

    @Test
    func `duplex receiver failure crosses to its peer outbound direction`() async {
        var (left, right) = Async.Channel<Int>.Duplex<Failure>.pair(capacity: 1)

        left.inbound.fail(.stopped(6))

        do throws(Async.Channel<Int>.Typed<Failure>.Error) {
            try await right.outbound.send(1)
            Issue.record("Expected inbound failure to reject the matching peer outbound")
        } catch {
            switch error {
            case .failed(.stopped(6)):
                break
            default:
                Issue.record("Expected the inbound declared failure on the peer outbound")
            }
        }
    }
}
