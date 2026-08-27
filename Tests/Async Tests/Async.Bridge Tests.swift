import Async_Test_Support
import Testing

@Suite
struct BridgeTests {

    @Test
    func `next() does not observe Task cancellation`() async {

        let bridge = Async.Bridge<Int>()

        let task = Task { await bridge.next() }

        try? await Task.sleep(for: .milliseconds(20))

        task.cancel()

        try? await Task.sleep(for: .milliseconds(20))

        bridge.push(42)

        let result = await task.value
        #expect(result == 42, "cancelled consumer still receives the pushed element")
        #expect(task.isCancelled, "task should still report itself as cancelled")
    }

    @Test
    func `next() returns nil after finish on cancelled task`() async {

        let bridge = Async.Bridge<Int>()

        let task = Task { await bridge.next() }

        try? await Task.sleep(for: .milliseconds(20))
        task.cancel()
        try? await Task.sleep(for: .milliseconds(20))

        bridge.finish()

        let result = await task.value
        #expect(result == nil, "cancelled consumer resumes with nil after finish()")
    }
}
