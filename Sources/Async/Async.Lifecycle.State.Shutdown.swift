extension Async.Lifecycle.State {

    @safe
    public struct Shutdown: ~Copyable, ~Escapable {
        @usableFromInline
        let pointer: UnsafeMutablePointer<Async.Lifecycle.State>

        @inlinable @_lifetime(borrow pointer)
        package init(_ pointer: UnsafeMutablePointer<Async.Lifecycle.State>) {
            unsafe self.pointer = pointer
        }
    }

    public var shutdown: Shutdown {
        mutating _read {
            yield unsafe Shutdown(&self)
        }
        mutating _modify {
            var view = unsafe Shutdown(&self)
            yield &view
        }
    }
}

extension Async.Lifecycle.State.Shutdown {

    @inlinable
    public var isActive: Bool { unsafe pointer.pointee != .open }

    @inlinable
    public var isComplete: Bool { unsafe pointer.pointee == .closed }

    @discardableResult
    @inlinable
    public func begin() -> Bool {
        guard unsafe pointer.pointee == .open else { return false }
        unsafe pointer.pointee = .closing
        return true
    }

    @discardableResult
    @inlinable
    public func complete() -> Bool {
        guard unsafe pointer.pointee == .closing else { return false }
        unsafe pointer.pointee = .closed
        return true
    }
}
