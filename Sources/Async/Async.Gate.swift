extension Async {

    public typealias Gate = Promise<Void>
}

extension Async.Promise where Value == Void {

    @discardableResult
    public func open() -> Bool {
        fulfill(())
    }

    public func wait(_ callback: @escaping @Sendable () -> Void) {
        (self as Async.Promise<Void>).wait { _ in callback() }
    }

    public var isOpen: Bool {
        isFulfilled
    }
}

#if !hasFeature(Embedded)
    extension Async.Promise where Value == Void {

        nonisolated(nonsending)
            public func wait() async
        {
            _ = await value()
        }
    }
#endif
