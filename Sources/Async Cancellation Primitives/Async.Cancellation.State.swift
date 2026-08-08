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

extension Async.Cancellation {
    /// Two-state terminal machine for cooperative cancellation.
    ///
    /// ## States
    ///
    /// - `active`: Normal operation; cancellation has not been requested.
    /// - `cancelled`: Terminal; cancellation was requested exactly once.
    ///
    /// ## Thread Safety
    ///
    /// This is a pure value type with no built-in synchronization.
    /// Consumers embed `State` in their own `Mutex`-protected state and
    /// call mutating methods while holding the lock — the same pattern as
    /// `Async.Lifecycle.State`.
    ///
    /// ## Terminal-State Law
    ///
    /// `cancel()` returns `true` for exactly the first transition. Once
    /// `cancelled`, the state never leaves `cancelled`.
    public enum State: Sendable, Equatable {
        /// Normal operation.
        case active

        /// Cancellation requested; terminal.
        case cancelled
    }
}

// MARK: - Queries

extension Async.Cancellation.State {
    /// Whether cancellation has been requested.
    @inlinable
    public var isCancelled: Bool {
        self == .cancelled
    }
}

// MARK: - Transitions

extension Async.Cancellation.State {
    /// Transitions to `cancelled`.
    ///
    /// - Returns: `true` if this call performed the transition
    ///   (state was `active`); `false` if already `cancelled`.
    @inlinable
    @discardableResult
    public mutating func cancel() -> Bool {
        guard self == .active else { return false }
        self = .cancelled
        return true
    }
}
