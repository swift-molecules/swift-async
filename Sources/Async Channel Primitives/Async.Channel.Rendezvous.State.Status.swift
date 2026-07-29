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

// Async channels require task suspension which is not available on embedded Swift.
#if !hasFeature(Embedded)

    extension Async.Channel.Rendezvous.State where Element: ~Copyable {
        enum Status: Sendable {
            case open
            case closed
        }
    }

#endif  // !hasFeature(Embedded)
