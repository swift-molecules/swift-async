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
    /// A handle for a handler registered on a cancellation source.
    ///
    /// Registrations preserve the exactly-once law: a handler either fires
    /// exactly once at cancellation, or is removed exactly once via
    /// ``deregister()`` and never fires. A registration returned for a
    /// handler that already ran (registration after cancellation) is spent;
    /// `deregister()` on it returns `false`.
    public struct Registration: Sendable {
        @usableFromInline
        let source: Async.Cancellation.Source

        /// `nil` when the registration was spent at creation because the
        /// source was already cancelled and the handler ran promptly.
        @usableFromInline
        let identifier: UInt64?

        @usableFromInline
        init(source: Async.Cancellation.Source, identifier: UInt64?) {
            self.source = source
            self.identifier = identifier
        }
    }
}

// MARK: - Deregistration

extension Async.Cancellation.Registration {
    /// Removes the registered handler if it has not fired.
    ///
    /// Idempotent under the exactly-once law: at most one call returns
    /// `true`, and only when the handler had not yet run.
    ///
    /// - Returns: `true` if the handler was removed before firing;
    ///   `false` if it already ran or was already removed.
    @discardableResult
    public func deregister() -> Bool {
        guard let identifier = self.identifier else { return false }
        return self.source._deregister(identifier)
    }
}
