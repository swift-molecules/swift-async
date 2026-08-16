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

internal import Async_Mutex_Primitives

extension Async.Cancellation {
    /// A thread-safe, exactly-once cancellation broadcaster.
    ///
    /// A source starts `active`, transitions to `cancelled` at most once,
    /// and runs every registered handler exactly once:
    /// - Handlers registered before `cancel()` run at the single
    ///   cancelling transition.
    /// - Handlers registered after `cancel()` run promptly, synchronously
    ///   at registration.
    /// - A handler removed via ``Async/Cancellation/Registration/deregister()``
    ///   before the transition never runs.
    ///
    /// ## Usage
    /// ```swift
    /// let source = Async.Cancellation.Source()
    /// let token = source.token
    ///
    /// let registration = token.onCancel { /* release resources */ }
    ///
    /// source.cancel()   // handler runs exactly once
    /// registration.deregister()  // no-op after the handler ran
    /// ```
    ///
    /// ## Thread Safety
    /// All operations are protected by an internal mutex. Handlers run
    /// outside the lock; a handler may safely call back into the source.
    public final class Source: Sendable {
        struct _State {
            var machine: Async.Cancellation.State = .active
            var nextIdentifier: UInt64 = 0
            var handlers: [UInt64: @Sendable () -> Void] = [:]
        }

        let _state: Async.Mutex<_State>

        /// Creates an active, uncancelled source.
        public init() {
            self._state = Async.Mutex(_State())
        }
    }
}

// MARK: - Queries

extension Async.Cancellation.Source {
    /// Whether cancellation has been requested.
    ///
    /// Terminal: once `true`, stays `true`.
    public var isCancelled: Bool {
        self._state.withLock { $0.machine.isCancelled }
    }

    /// A read-and-observe view of this source for handing to consumers.
    public var token: Async.Cancellation.Token {
        Async.Cancellation.Token(source: self)
    }
}

// MARK: - Cancellation

extension Async.Cancellation.Source {
    /// Requests cancellation.
    ///
    /// The first call transitions the source to `cancelled` and runs every
    /// registered handler exactly once, outside the internal lock, in
    /// registration order. Subsequent calls are no-ops.
    ///
    /// - Returns: `true` if this call performed the transition;
    ///   `false` if the source was already cancelled.
    @discardableResult
    public func cancel() -> Bool {
        let fired: [(UInt64, @Sendable () -> Void)]? = self._state.withLock { state in
            guard state.machine.cancel() else { return nil }
            let handlers = state.handlers.sorted { $0.key < $1.key }
            state.handlers.removeAll()
            return handlers.map { ($0.key, $0.value) }
        }
        guard let fired else { return false }
        for (_, handler) in fired {
            handler()
        }
        return true
    }
}

// MARK: - Registration

extension Async.Cancellation.Source {
    /// Registers a handler to run exactly once when this source cancels.
    ///
    /// If the source is already cancelled, the handler runs promptly and
    /// synchronously before this method returns, and the returned
    /// registration is already spent.
    ///
    /// - Parameter handler: Runs exactly once on cancellation.
    /// - Returns: A registration that can remove the handler before it fires.
    public func onCancel(
        _ handler: @escaping @Sendable () -> Void
    ) -> Async.Cancellation.Registration {
        let identifier: UInt64? = self._state.withLock { state in
            guard !state.machine.isCancelled else { return nil }
            let identifier = state.nextIdentifier
            state.nextIdentifier &+= 1
            state.handlers[identifier] = handler
            return identifier
        }
        guard let identifier else {
            // Prompt-cancellation guarantee: already cancelled, run now.
            handler()
            return Async.Cancellation.Registration(source: self, identifier: nil)
        }
        return Async.Cancellation.Registration(source: self, identifier: identifier)
    }

    /// Removes the handler with the given identifier if it has not fired.
    ///
    /// - Returns: `true` if the handler was removed before firing.
    func _deregister(_ identifier: UInt64) -> Bool {
        self._state.withLock { state in
            state.handlers.removeValue(forKey: identifier) != nil
        }
    }
}
