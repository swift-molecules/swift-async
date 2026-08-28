public import Synchronization

extension Async.Waiter {

    public final class Flag: Sendable {
        @usableFromInline
        let _bits: Atomic<UInt8>

        public init() {
            self._bits = Atomic(0)
        }
    }
}

extension Async.Waiter.Flag {
    @usableFromInline
    static let cancelledBit: UInt8 = 1

    @usableFromInline
    static let timedOutBit: UInt8 = 2

    public var cancelled: Bool {
        _bits.load(ordering: .relaxed) & Self.cancelledBit != 0
    }

    public var timedOut: Bool {
        _bits.load(ordering: .relaxed) & Self.timedOutBit != 0
    }

    public var isFlagged: Bool {
        _bits.load(ordering: .relaxed) != 0
    }

    @discardableResult
    public func cancel() -> Bool {
        setFlag(Self.cancelledBit)
    }

    @discardableResult
    public func timeout() -> Bool {
        setFlag(Self.timedOutBit)
    }

    private func setFlag(_ mask: UInt8) -> Bool {
        var current = _bits.load(ordering: .relaxed)
        while true {
            let next = current | mask
            if next == current {

                return false
            }
            let result = _bits.compareExchange(
                expected: current,
                desired: next,
                ordering: .relaxed
            )
            if result.exchanged {
                return true
            }

            current = result.original
        }
    }
}
