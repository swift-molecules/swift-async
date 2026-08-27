extension Async {

    public enum Precedence {}
}

extension Async.Precedence {

    @inlinable
    public static func resolve<Outcome>(
        shutdown: Bool,
        cancelled: Bool,
        timedOut: Bool,
        success: @autoclosure () -> Outcome,
        onShutdown: @autoclosure () -> Outcome,
        onCancelled: @autoclosure () -> Outcome,
        onTimeout: @autoclosure () -> Outcome
    ) -> Outcome {
        if shutdown { return onShutdown() }
        if cancelled { return onCancelled() }
        if timedOut { return onTimeout() }
        return success()
    }

}
