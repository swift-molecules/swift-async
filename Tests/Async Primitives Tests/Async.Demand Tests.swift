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

import Async_Primitives_Test_Support
import Testing

/// Test namespace for Async.Demand.
enum Demand {
    enum Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
    }
}

// MARK: - Unit (law fixtures)

extension Demand.Test.Unit {
    /// Law: a producer emits no more elements than demand permits.
    @Test
    func fulfillConsumesExactlyTheRequestedCount() {
        var demand = Async.Demand.count(3)
        let first = demand.fulfill()
        let second = demand.fulfill()
        let third = demand.fulfill()
        let fourth = demand.fulfill()
        #expect(first)
        #expect(second)
        #expect(third)
        #expect(!fourth)
        #expect(demand.isNone)
    }

    /// Law: cancellation releases pending demand exactly once.
    @Test
    func releaseReturnsOutstandingDemandAndZeroes() {
        var demand = Async.Demand.count(5)
        let released = demand.release()
        #expect(released == .count(5))
        #expect(demand.isNone)
        let secondRelease = demand.release()
        #expect(secondRelease == .none)
        let fulfilled = demand.fulfill()
        #expect(!fulfilled)
    }

    /// Unlimited demand fulfills without counting.
    @Test
    func unlimitedFulfillsWithoutCounting() {
        var demand = Async.Demand.unlimited
        for _ in 0..<1000 {
            let fulfilled = demand.fulfill()
            #expect(fulfilled)
        }
        #expect(demand.isUnlimited)
        #expect(demand.count == nil)
    }

    /// Addition accumulates consumer requests.
    @Test
    func addingAccumulates() {
        var demand = Async.Demand.none
        demand.add(.count(2))
        demand.add(.count(3))
        #expect(demand == .count(5))
        #expect(demand.count == 5)
    }

    /// Unlimited absorbs addition and subtraction.
    @Test
    func unlimitedAbsorbs() {
        #expect(Async.Demand.unlimited.adding(.count(1)) == .unlimited)
        #expect(Async.Demand.count(1).adding(.unlimited) == .unlimited)
        #expect(Async.Demand.unlimited.subtracting(.count(9)) == .unlimited)
        #expect(Async.Demand.count(9).subtracting(.unlimited) == .none)
    }

    /// Ordering: none < finite < unlimited.
    @Test
    func comparableOrdering() {
        #expect(Async.Demand.none < .count(1))
        #expect(Async.Demand.count(1) < .count(2))
        #expect(Async.Demand.count(.max) < .unlimited)
        #expect(Async.Demand.none < .unlimited)
    }
}

// MARK: - Edge cases

extension Demand.Test.EdgeCase {
    /// Zero-length: `.count(0)` is `.none`.
    @Test
    func zeroCountIsNone() {
        #expect(Async.Demand.count(0) == .none)
        #expect(Async.Demand.count(0).isNone)
        #expect(!Async.Demand.count(0).isUnlimited)
    }

    /// Boundary capacity: finite arithmetic saturates at the largest
    /// finite count and never silently becomes unlimited.
    @Test
    func finiteAdditionSaturatesBelowUnlimited() {
        let maximum = Async.Demand.count(Async.Demand.maximumFiniteCount)
        let saturated = maximum.adding(.count(1))
        #expect(saturated == maximum)
        #expect(!saturated.isUnlimited)
        #expect(Async.Demand.count(.max) == maximum)
        let doubled = maximum.adding(maximum)
        #expect(doubled == maximum)
        #expect(!doubled.isUnlimited)
    }

    /// Terminal state: subtraction saturates at none.
    @Test
    func subtractionSaturatesAtNone() {
        #expect(Async.Demand.count(2).subtracting(.count(5)) == .none)
        #expect(Async.Demand.none.subtracting(.count(1)) == .none)
    }
}
