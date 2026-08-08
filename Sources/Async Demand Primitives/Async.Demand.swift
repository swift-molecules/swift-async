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
    /// Downstream demand for backpressured production.
    ///
    /// Demand is the count of elements a consumer permits a producer to
    /// emit. It is the vocabulary type composed by channel, streaming and
    /// networking layers: a producer emits no more elements than the
    /// outstanding demand permits.
    ///
    /// ## Representation
    ///
    /// Demand is either a finite count or `unlimited`. Finite arithmetic
    /// saturates at the largest finite count; `unlimited` absorbs addition
    /// and subtraction.
    ///
    /// ## Usage
    /// ```swift
    /// var outstanding = Async.Demand.none
    /// outstanding.add(.count(8))          // consumer requests 8
    /// if outstanding.fulfill() {          // producer emits one element
    ///     // element emitted; outstanding is now 7
    /// }
    /// ```
    public struct Demand: Sendable, Hashable {
        /// Raw representation: `UInt64.max` is the `unlimited` sentinel;
        /// every other value is a finite count.
        @usableFromInline
        var rawValue: UInt64

        @usableFromInline
        init(rawValue: UInt64) {
            self.rawValue = rawValue
        }
    }
}

// MARK: - Factories

extension Async.Demand {
    /// The largest representable finite count.
    @inlinable
    public static var maximumFiniteCount: UInt64 { .max - 1 }

    /// No demand: the producer must not emit.
    @inlinable
    public static var none: Self {
        Self(rawValue: 0)
    }

    /// Unlimited demand: the producer may emit without counting.
    @inlinable
    public static var unlimited: Self {
        Self(rawValue: .max)
    }

    /// A finite demand for the given number of elements.
    ///
    /// Counts above ``maximumFiniteCount`` clamp to ``maximumFiniteCount``;
    /// finite demand never silently becomes ``unlimited``.
    ///
    /// - Parameter count: The number of elements the consumer permits.
    @inlinable
    public static func count(_ count: UInt64) -> Self {
        Self(rawValue: min(count, Self.maximumFiniteCount))
    }
}

// MARK: - Queries

extension Async.Demand {
    /// Whether this demand is unlimited.
    @inlinable
    public var isUnlimited: Bool {
        self.rawValue == .max
    }

    /// Whether this demand permits no emission.
    @inlinable
    public var isNone: Bool {
        self.rawValue == 0
    }

    /// The finite count, or `nil` when unlimited.
    @inlinable
    public var count: UInt64? {
        self.isUnlimited ? nil : self.rawValue
    }
}

// MARK: - Arithmetic

extension Async.Demand {
    /// Returns this demand increased by additional requested demand.
    ///
    /// `unlimited` absorbs: adding anything to `unlimited`, or `unlimited`
    /// to anything, is `unlimited`. Finite addition saturates at
    /// ``maximumFiniteCount``.
    @inlinable
    public func adding(_ other: Self) -> Self {
        if self.isUnlimited || other.isUnlimited { return .unlimited }
        let (sum, overflow) = self.rawValue.addingReportingOverflow(other.rawValue)
        if overflow { return Self(rawValue: Self.maximumFiniteCount) }
        return Self(rawValue: min(sum, Self.maximumFiniteCount))
    }

    /// Returns this demand decreased by fulfilled emission.
    ///
    /// `unlimited` absorbs: subtracting from `unlimited` stays `unlimited`.
    /// Finite subtraction saturates at ``none``. Subtracting `unlimited`
    /// from a finite demand is ``none``.
    @inlinable
    public func subtracting(_ other: Self) -> Self {
        if self.isUnlimited { return .unlimited }
        if other.isUnlimited { return .none }
        return Self(rawValue: self.rawValue - min(other.rawValue, self.rawValue))
    }

    /// Increases this demand in place by additional requested demand.
    @inlinable
    public mutating func add(_ other: Self) {
        self = self.adding(other)
    }

    /// Consumes one unit of demand for a single emission.
    ///
    /// - Returns: `true` if a unit of demand was available (the producer
    ///   may emit one element); `false` if demand was ``none``.
    ///   `unlimited` fulfills without counting and stays `unlimited`.
    @inlinable
    @discardableResult
    public mutating func fulfill() -> Bool {
        if self.isUnlimited { return true }
        guard self.rawValue > 0 else { return false }
        self.rawValue -= 1
        return true
    }

    /// Releases all outstanding demand.
    ///
    /// The cancellation law for backpressured production: cancellation
    /// releases pending demand; the producer must not emit afterwards.
    ///
    /// - Returns: The demand that was outstanding before the release.
    @inlinable
    @discardableResult
    public mutating func release() -> Self {
        let outstanding = self
        self = .none
        return outstanding
    }
}

// MARK: - Comparable

extension Async.Demand: Comparable {
    /// Orders demand by permitted emission; `unlimited` is the greatest.
    @inlinable
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
