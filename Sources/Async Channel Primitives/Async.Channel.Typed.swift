// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-async open source project
//
// Copyright (c) 2025 Coen ten Thije Boonkkamp and the swift-async project authors
// Licensed under Apache License v2.0
//
// ===----------------------------------------------------------------------===//

#if !hasFeature(Embedded)

    extension Async {
        /// A bounded, directional channel with a declared terminal failure type.
        ///
        /// The sender owns element production and may `finish()` or `fail(_)` the
        /// receiver. The receiver owns consumption and may likewise terminate the
        /// sender. A successful sender finish drains already-buffered elements and
        /// then makes `receive()` return `nil`; a sender failure drains those same
        /// elements and then makes `receive()` throw `.failed(_)`.
        public typealias Channel<Element: ~Copyable, Failure: Swift.Error & Sendable> = _Channel<Element>.Typed<Failure>
    }

    extension Async._Channel where Element: ~Copyable {
        /// Typed terminal semantics composed over the channel's bounded machinery.
        public struct Typed<Failure: Swift.Error & Sendable> {}
    }

    extension Async._Channel.Typed where Element: ~Copyable, Failure: Swift.Error & Sendable {
        /// Errors emitted by typed endpoint operations.
        public typealias Error = _TypedChannelError<Failure>
    }

#endif  // !hasFeature(Embedded)
