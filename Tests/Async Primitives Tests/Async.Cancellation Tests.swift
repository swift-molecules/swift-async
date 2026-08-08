// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-async open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-async project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Async_Primitives_Test_Support
import Synchronization
import Testing

/// Test namespace for Async.Cancellation.
enum Cancellation {
    enum Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Concurrency {}
    }
}

// MARK: - Unit (law fixtures)

extension Cancellation.Test.Unit {
    /// Law: cancellation is terminal — exactly one transition.
    @Test
    func stateTransitionsExactlyOnce() {
        var state = Async.Cancellation.State.active
        #expect(!state.isCancelled)
        #expect(state.cancel())
        #expect(state.isCancelled)
        #expect(!state.cancel())
        #expect(state.isCancelled)
    }

    /// Law: source cancels exactly once and stays cancelled.
    @Test
    func sourceCancelsExactlyOnce() {
        let source = Async.Cancellation.Source()
        #expect(!source.isCancelled)
        #expect(source.cancel())
        #expect(source.isCancelled)
        #expect(!source.cancel())
        #expect(source.isCancelled)
    }

    /// Law: a handler registered before cancellation runs exactly once.
    @Test
    func handlerRunsExactlyOnceAtCancellation() {
        let source = Async.Cancellation.Source()
        let count = Atomic<Int>(0)
        let registration = source.onCancel { count.wrappingAdd(1, ordering: .relaxed) }
        #expect(count.load(ordering: .relaxed) == 0)
        source.cancel()
        #expect(count.load(ordering: .relaxed) == 1)
        source.cancel()
        #expect(count.load(ordering: .relaxed) == 1)
        // Already fired: deregistration reports false.
        #expect(!registration.deregister())
    }

    /// Prompt guarantee: registration after cancellation runs synchronously.
    @Test
    func handlerRegisteredAfterCancellationRunsPromptly() {
        let source = Async.Cancellation.Source()
        source.cancel()
        let count = Atomic<Int>(0)
        let registration = source.onCancel { count.wrappingAdd(1, ordering: .relaxed) }
        #expect(count.load(ordering: .relaxed) == 1)
        #expect(!registration.deregister())
    }

    /// A deregistered handler never runs; deregistration is exactly-once.
    @Test
    func deregisteredHandlerNeverRuns() {
        let source = Async.Cancellation.Source()
        let count = Atomic<Int>(0)
        let registration = source.onCancel { count.wrappingAdd(1, ordering: .relaxed) }
        #expect(registration.deregister())
        #expect(!registration.deregister())
        source.cancel()
        #expect(count.load(ordering: .relaxed) == 0)
    }

    /// Token mirrors the source's terminal state and observation surface.
    @Test
    func tokenObservesSourceState() throws {
        let source = Async.Cancellation.Source()
        let token = source.token
        #expect(!token.isCancelled)
        try token.checkCancellation()
        source.cancel()
        #expect(token.isCancelled)
        #expect(throws: Async.Cancellation.Error.cancelled) {
            try token.checkCancellation()
        }
    }
}

// MARK: - Edge cases

extension Cancellation.Test.EdgeCase {
    /// Zero handlers: cancellation with an empty registry still transitions.
    @Test
    func cancelWithNoHandlers() {
        let source = Async.Cancellation.Source()
        #expect(source.cancel())
        #expect(source.isCancelled)
    }

    /// Handlers run in registration order at the cancelling transition.
    @Test
    func handlersRunInRegistrationOrder() {
        let source = Async.Cancellation.Source()
        let order = Async.Mutex<[Int]>([])
        for index in 0..<8 {
            _ = source.onCancel { order.withLock { $0.append(index) } }
        }
        source.cancel()
        #expect(order.withLock { $0 } == Array(0..<8))
    }

    /// Reentrancy: a handler may call back into the source without deadlock.
    @Test
    func handlerMayReenterSource() {
        let source = Async.Cancellation.Source()
        let observed = Atomic<Bool>(false)
        _ = source.onCancel {
            // Runs outside the lock: querying and re-cancelling are safe.
            if source.isCancelled, !source.cancel() {
                observed.store(true, ordering: .relaxed)
            }
        }
        source.cancel()
        #expect(observed.load(ordering: .relaxed))
    }
}

// MARK: - Concurrency

extension Cancellation.Test.Concurrency {
    /// Law: concurrent cancellation performs exactly one transition and
    /// resumes every handler exactly once.
    @Test
    func concurrentCancelIsExactlyOnce() async {
        let source = Async.Cancellation.Source()
        let handlerRuns = Atomic<Int>(0)
        let transitions = Atomic<Int>(0)
        for _ in 0..<16 {
            _ = source.onCancel { handlerRuns.wrappingAdd(1, ordering: .relaxed) }
        }
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<32 {
                group.addTask {
                    if source.cancel() {
                        transitions.wrappingAdd(1, ordering: .relaxed)
                    }
                }
            }
        }
        #expect(transitions.load(ordering: .relaxed) == 1)
        #expect(handlerRuns.load(ordering: .relaxed) == 16)
    }

    /// Racing registration against cancellation: every handler runs
    /// exactly once regardless of which side wins the race.
    @Test
    func registrationRacesCancellation() async {
        for _ in 0..<64 {
            let source = Async.Cancellation.Source()
            let runs = Atomic<Int>(0)
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    _ = source.onCancel { runs.wrappingAdd(1, ordering: .relaxed) }
                }
                group.addTask {
                    source.cancel()
                }
            }
            #expect(runs.load(ordering: .relaxed) == 1)
        }
    }
}
