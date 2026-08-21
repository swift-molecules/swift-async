import Async_Primitives_Test_Support
import Testing

@Suite
struct AsyncTests {

    @Test
    func `Async namespace exists`() {
        _ = Async.self
        _ = Async.Channel<Never>.self
    }
}
