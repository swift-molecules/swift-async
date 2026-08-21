extension Async {

    public struct Demand: Sendable, Hashable {

        @usableFromInline
        var rawValue: UInt64

        @usableFromInline
        init(rawValue: UInt64) {
            self.rawValue = rawValue
        }
    }
}

extension Async.Demand {

    @inlinable
    public static var maximumFiniteCount: UInt64 { .max - 1 }

    @inlinable
    public static var none: Self {
        Self(rawValue: 0)
    }

    @inlinable
    public static var unlimited: Self {
        Self(rawValue: .max)
    }

    @inlinable
    public static func count(_ count: UInt64) -> Self {
        Self(rawValue: min(count, Self.maximumFiniteCount))
    }
}

extension Async.Demand {

    @inlinable
    public var isUnlimited: Bool {
        self.rawValue == .max
    }

    @inlinable
    public var isNone: Bool {
        self.rawValue == 0
    }

    @inlinable
    public var count: UInt64? {
        self.isUnlimited ? nil : self.rawValue
    }
}

extension Async.Demand {

    @inlinable
    public func adding(_ other: Self) -> Self {
        if self.isUnlimited || other.isUnlimited { return .unlimited }
        let (sum, overflow) = self.rawValue.addingReportingOverflow(other.rawValue)
        if overflow { return Self(rawValue: Self.maximumFiniteCount) }
        return Self(rawValue: min(sum, Self.maximumFiniteCount))
    }

    @inlinable
    public func subtracting(_ other: Self) -> Self {
        if self.isUnlimited { return .unlimited }
        if other.isUnlimited { return .none }
        return Self(rawValue: self.rawValue - min(other.rawValue, self.rawValue))
    }

    @inlinable
    public mutating func add(_ other: Self) {
        self = self.adding(other)
    }

    @inlinable
    @discardableResult
    public mutating func fulfill() -> Bool {
        if self.isUnlimited { return true }
        guard self.rawValue > 0 else { return false }
        self.rawValue -= 1
        return true
    }

    @inlinable
    @discardableResult
    public mutating func release() -> Self {
        let outstanding = self
        self = .none
        return outstanding
    }
}

extension Async.Demand: Comparable {

    @inlinable
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
