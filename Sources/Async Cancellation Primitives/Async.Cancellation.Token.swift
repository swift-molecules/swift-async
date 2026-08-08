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
    /// A read-and-observe view over a cancellation source.
    ///
    /// Tokens are handed to consumers so they can observe and react to
    /// cancellation without being able to request it — only the
    /// ``Async/Cancellation/Source`` owner can cancel.
    ///
    /// ## Usage
    /// ```swift
    /// func produce(until token: Async.Cancellation.Token) throws(Async.Cancellation.Error) {
    ///     while !token.isCancelled {
    ///         // produce next element
    ///     }
    ///     throw .cancelled
    /// }
    /// ```
    public struct Token: Sendable {
        @usableFromInline
        let source: Async.Cancellation.Source

        @usableFromInline
        init(source: Async.Cancellation.Source) {
            self.source = source
        }
    }
}

// MARK: - Queries

extension Async.Cancellation.Token {
    /// Whether cancellation has been requested.
    ///
    /// Terminal: once `true`, stays `true`.
    @inlinable
    public var isCancelled: Bool {
        self.source.isCancelled
    }

    /// Throws ``Async/Cancellation/Error/cancelled`` if cancellation
    /// has been requested.
    @inlinable
    public func checkCancellation() throws(Async.Cancellation.Error) {
        if self.source.isCancelled {
            throw .cancelled
        }
    }
}

// MARK: - Observation

extension Async.Cancellation.Token {
    /// Registers a handler to run exactly once when the source cancels.
    ///
    /// If the source is already cancelled, the handler runs promptly and
    /// synchronously before this method returns.
    ///
    /// - Parameter handler: Runs exactly once on cancellation.
    /// - Returns: A registration that can remove the handler before it fires.
    @inlinable
    @discardableResult
    public func onCancel(
        _ handler: @escaping @Sendable () -> Void
    ) -> Async.Cancellation.Registration {
        self.source.onCancel(handler)
    }
}
