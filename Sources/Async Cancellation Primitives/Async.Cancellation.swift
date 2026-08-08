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

extension Async {
    /// Namespace for prompt cooperative cancellation primitives.
    ///
    /// Provides the cancellation vocabulary composed by streaming and
    /// networking layers:
    /// - `Cancellation.State`: Pure two-state machine (active → cancelled)
    /// - `Cancellation.Source`: Thread-safe cancellation broadcaster
    /// - `Cancellation.Token`: Read-and-observe view handed to consumers
    /// - `Cancellation.Registration`: Exactly-once handler registration
    /// - `Cancellation.Error`: Typed error for cancelled operations
    ///
    /// ## Laws
    /// - Cancellation is terminal: once cancelled, a source stays cancelled,
    ///   and every observer sees the same terminal state.
    /// - Every registered handler runs exactly once — either at the single
    ///   `cancel()` transition or, when registered after cancellation,
    ///   promptly at registration.
    /// - Cancellation neither invents nor absorbs endpoint semantics;
    ///   consumers own what "cancelled" means for their resource.
    public enum Cancellation {}
}
