// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-async open source project
//
// Copyright (c) 2025-2026 Coen ten Thije Boonkkamp and the swift-async project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Async_Primitives_Test_Support
import Testing

@Suite
struct `Rendezvous Tests` {
    @Suite
    struct Unit {}

    @Suite
    struct `Edge Case` {}

    @Suite
    struct Integration {}

    actor Sender {
        let handle: Async.Channel<Int>.Rendezvous.Sender
        var admitted = 0
        var completed = 0

        init(_ handle: Async.Channel<Int>.Rendezvous.Sender) {
            self.handle = handle
        }
    }

    actor Receiver {
        let handle: Async.Channel<Int>.Rendezvous.Receiver
        var admitted = 0
        var completed = 0

        init(_ handle: Async.Channel<Int>.Rendezvous.Receiver) {
            self.handle = handle
        }
    }

    final class Payload {
        let value: Int

        init(_ value: Int) {
            self.value = value
        }
    }

    struct Parcel: ~Copyable {
        let payload: Payload
    }

    actor Sink {}
}

extension `Rendezvous Tests`.Sender {
    func send(_ element: Int) async -> Async.Channel<Int>.Error? {
        admitted += 1
        do throws(Async.Channel<Int>.Error) {
            try await handle.send(element)
            completed += 1
            return nil
        } catch {
            completed += 1
            return error
        }
    }

    func counts() -> (admitted: Int, completed: Int) {
        (admitted, completed)
    }
}

extension `Rendezvous Tests`.Receiver {
    func receive() async -> Result<Int?, Async.Channel<Int>.Error> {
        admitted += 1
        do throws(Async.Channel<Int>.Error) {
            let element = try await handle.receive()
            completed += 1
            return .success(element)
        } catch {
            completed += 1
            return .failure(error)
        }
    }

    func counts() -> (admitted: Int, completed: Int) {
        (admitted, completed)
    }
}

extension `Rendezvous Tests`.Sink {
    func receive(
        from receiver: Async.Channel<`Rendezvous Tests`.Parcel>.Rendezvous.Receiver
    ) async -> Int? {
        do throws(Async.Channel<`Rendezvous Tests`.Parcel>.Error) {
            guard let parcel = try await receiver.receive() else { return nil }
            return parcel.payload.value
        } catch {
            return nil
        }
    }
}

extension `Rendezvous Tests` {
    static func wait(
        for expected: Int,
        in sender: Sender
    ) async -> (admitted: Int, completed: Int) {
        while true {
            let counts = await sender.counts()
            if counts.admitted == expected { return counts }
            await Task.yield()
        }
    }

    static func wait(
        for expected: Int,
        in receiver: Receiver
    ) async -> (admitted: Int, completed: Int) {
        while true {
            let counts = await receiver.counts()
            if counts.admitted == expected { return counts }
            await Task.yield()
        }
    }
}

extension `Rendezvous Tests`.Unit {
    @Test
    func `send remains suspended until a receiver accepts the element`() async throws {
        let channel = Async.Channel<Int>.Rendezvous()
        let sender = `Rendezvous Tests`.Sender(channel.sender)
        let task = Task { await sender.send(42) }

        let before = await `Rendezvous Tests`.wait(for: 1, in: sender)
        #expect(before.completed == 0)

        let received = try await channel.receiver.receive()
        #expect(received == 42)
        #expect(await task.value == nil)

        let after = await sender.counts()
        #expect(after.completed == 1)
    }

    @Test
    func `waiting senders are accepted in FIFO order`() async throws {
        let channel = Async.Channel<Int>.Rendezvous()
        let sender = `Rendezvous Tests`.Sender(channel.sender)

        let first = Task { await sender.send(1) }
        #expect(await `Rendezvous Tests`.wait(for: 1, in: sender).completed == 0)

        let second = Task { await sender.send(2) }
        #expect(await `Rendezvous Tests`.wait(for: 2, in: sender).completed == 0)

        let third = Task { await sender.send(3) }
        #expect(await `Rendezvous Tests`.wait(for: 3, in: sender).completed == 0)

        let one = try await channel.receiver.receive()
        let two = try await channel.receiver.receive()
        let three = try await channel.receiver.receive()

        #expect([one, two, three] == [1, 2, 3])
        #expect(await first.value == nil)
        #expect(await second.value == nil)
        #expect(await third.value == nil)
    }

    @Test
    func `waiting receivers are accepted in FIFO order`() async throws {
        let channel = Async.Channel<Int>.Rendezvous()
        let receiver = `Rendezvous Tests`.Receiver(channel.receiver)

        let first = Task { await receiver.receive() }
        #expect(await `Rendezvous Tests`.wait(for: 1, in: receiver).completed == 0)

        let second = Task { await receiver.receive() }
        #expect(await `Rendezvous Tests`.wait(for: 2, in: receiver).completed == 0)

        let third = Task { await receiver.receive() }
        #expect(await `Rendezvous Tests`.wait(for: 3, in: receiver).completed == 0)

        try await channel.sender.send(1)
        try await channel.sender.send(2)
        try await channel.sender.send(3)

        #expect(await first.value == .success(1))
        #expect(await second.value == .success(2))
        #expect(await third.value == .success(3))
    }

    @Test
    func `receiver handle copies compete safely`() async throws {
        let channel = Async.Channel<Int>.Rendezvous()
        let firstReceiver = `Rendezvous Tests`.Receiver(channel.receiver)
        let secondReceiver = `Rendezvous Tests`.Receiver(channel.receiver)

        let first = Task { await firstReceiver.receive() }
        #expect(await `Rendezvous Tests`.wait(for: 1, in: firstReceiver).completed == 0)

        let second = Task { await secondReceiver.receive() }
        #expect(await `Rendezvous Tests`.wait(for: 1, in: secondReceiver).completed == 0)

        try await channel.sender.send(10)
        try await channel.sender.send(20)

        #expect(await first.value == .success(10))
        #expect(await second.value == .success(20))
    }
}

extension `Rendezvous Tests`.`Edge Case` {
    @Test
    func `cancelling one send withdraws only that sender`() async throws {
        let channel = Async.Channel<Int>.Rendezvous()
        let sender = `Rendezvous Tests`.Sender(channel.sender)

        let cancelled = Task { await sender.send(1) }
        _ = await `Rendezvous Tests`.wait(for: 1, in: sender)
        cancelled.cancel()
        #expect(await cancelled.value == .cancelled)
        let isClosedAfterCancellation = channel.isClosed
        #expect(isClosedAfterCancellation == false)

        let accepted = Task { await sender.send(2) }
        _ = await `Rendezvous Tests`.wait(for: 2, in: sender)
        let received = try await channel.receiver.receive()
        #expect(received == 2)
        #expect(await accepted.value == nil)
    }

    @Test
    func `cancelling one receive withdraws only that receiver`() async throws {
        let channel = Async.Channel<Int>.Rendezvous()
        let receiver = `Rendezvous Tests`.Receiver(channel.receiver)

        let cancelled = Task { await receiver.receive() }
        _ = await `Rendezvous Tests`.wait(for: 1, in: receiver)
        cancelled.cancel()
        #expect(await cancelled.value == .failure(.cancelled))
        let isClosedAfterCancellation = channel.isClosed
        #expect(isClosedAfterCancellation == false)

        let accepted = Task { await receiver.receive() }
        _ = await `Rendezvous Tests`.wait(for: 2, in: receiver)
        try await channel.sender.send(2)
        #expect(await accepted.value == .success(2))
    }

    @Test
    func `close wakes pending and future operations with typed terminal results`() async {
        let sendChannel = Async.Channel<Int>.Rendezvous()
        let sender = `Rendezvous Tests`.Sender(sendChannel.sender)
        let pendingSend = Task { await sender.send(1) }
        _ = await `Rendezvous Tests`.wait(for: 1, in: sender)

        sendChannel.close()
        sendChannel.close()

        #expect(await pendingSend.value == .closed)
        let channelIsClosed = sendChannel.isClosed
        let senderIsClosed = sendChannel.sender.isClosed
        let receiverIsClosed = sendChannel.receiver.isClosed
        #expect(channelIsClosed)
        #expect(senderIsClosed)
        #expect(receiverIsClosed)

        let futureSend = await `Rendezvous Tests`.Sender(sendChannel.sender).send(2)
        #expect(futureSend == .closed)

        let receiveChannel = Async.Channel<Int>.Rendezvous()
        let receiver = `Rendezvous Tests`.Receiver(receiveChannel.receiver)
        let pendingReceive = Task { await receiver.receive() }
        _ = await `Rendezvous Tests`.wait(for: 1, in: receiver)

        receiveChannel.close()

        #expect(await pendingReceive.value == .success(nil))
        #expect(await receiver.receive() == .success(nil))
    }
}

extension `Rendezvous Tests`.Integration {
    @Test
    func `concurrent handle copies neither lose nor duplicate elements`() async {
        let channel = Async.Channel<Int>.Rendezvous()
        let sender = channel.sender
        let receiver = channel.receiver
        let count = 64

        let receiveTask = Task {
            await withTaskGroup(
                of: Result<Int?, Async.Channel<Int>.Error>.self,
                returning: [Result<Int?, Async.Channel<Int>.Error>].self
            ) { group in
                (0..<count).forEach { _ in
                    group.addTask {
                        do throws(Async.Channel<Int>.Error) {
                            return .success(try await receiver.receive())
                        } catch {
                            return .failure(error)
                        }
                    }
                }

                var results: [Result<Int?, Async.Channel<Int>.Error>] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }
        }

        let sendErrors = await withTaskGroup(
            of: Async.Channel<Int>.Error?.self,
            returning: [Async.Channel<Int>.Error].self
        ) { group in
            (0..<count).forEach { element in
                group.addTask {
                    do throws(Async.Channel<Int>.Error) {
                        try await sender.send(element)
                        return nil
                    } catch {
                        return error
                    }
                }
            }

            var errors: [Async.Channel<Int>.Error] = []
            for await error in group {
                if let error { errors.append(error) }
            }
            return errors
        }

        let receiveResults = await receiveTask.value
        var values: Set<Int> = []
        var receiveErrors: [Async.Channel<Int>.Error] = []
        for result in receiveResults {
            switch result {
            case .success(let element):
                if let element { values.insert(element) }

            case .failure(let error):
                receiveErrors.append(error)
            }
        }

        #expect(sendErrors.isEmpty)
        #expect(receiveErrors.isEmpty)
        #expect(values == Set(0..<count))
    }

    @Test
    func `non-Sendable noncopyable element crosses an actor boundary`() async throws {
        let channel = Async.Channel<`Rendezvous Tests`.Parcel>.Rendezvous()
        let sink = `Rendezvous Tests`.Sink()
        let receive = Task {
            await sink.receive(from: channel.receiver)
        }

        try await channel.sender.send(
            `Rendezvous Tests`.Parcel(payload: `Rendezvous Tests`.Payload(99))
        )

        #expect(await receive.value == 99)
    }
}
