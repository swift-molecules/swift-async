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
    /// Typed error thrown by operations that observe cancellation.
    ///
    /// A dedicated leaf error so that consumers can carry cancellation in
    /// `throws(Async.Cancellation.Error)` signatures or embed it as a case
    /// in their own typed error enums.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The operation was cancelled before it completed.
        case cancelled
    }
}
