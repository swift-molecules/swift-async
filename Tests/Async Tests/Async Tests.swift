import Async
import Testing

@Suite
struct AsyncTests {

    @Test
    func `Async namespace exists`() {
        _ = Async.self
    }
}
