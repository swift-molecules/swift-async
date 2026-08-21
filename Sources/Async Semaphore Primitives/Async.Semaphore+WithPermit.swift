#if !hasFeature(Embedded)

    public import Either_Primitives

    extension Async.Semaphore {

        nonisolated(nonsending)
            public func withPermit<T: Sendable, E: Swift.Error>(
                _ body: sending @escaping () async throws(E) -> sending T
            ) async throws(Either<Async.Semaphore.Error, E>) -> sending T
        {

            do throws(Async.Semaphore.Error) {
                try await wait()
            } catch {
                throw .left(error)
            }
            do throws(E) {
                let result = try await body()
                signal()
                return result
            } catch {
                signal()
                throw .right(error)
            }
        }
    }
#endif
