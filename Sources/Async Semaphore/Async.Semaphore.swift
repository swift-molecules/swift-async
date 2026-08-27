internal import Async_Mutex
public import Async_Primitive
public import Async_Promise

extension Async {

    public final class Semaphore: Sendable {
        @usableFromInline
        let _state: Async.Mutex<State>

        @usableFromInline
        let _shutdownGate: Async.Gate

        public init(capacity: Int) {
            precondition(capacity >= 1, "Semaphore requires capacity >= 1")
            self._state = Async.Mutex(State(capacity: capacity))
            self._shutdownGate = Async.Gate()
        }
    }
}
