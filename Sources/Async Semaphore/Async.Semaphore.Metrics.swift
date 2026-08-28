extension Async.Semaphore {

    public struct Metrics: Sendable, Equatable {

        public var acquisitions: UInt64

        public var releases: UInt64

        public var timeouts: UInt64

        public var cancellations: UInt64

        public var peakOutstanding: Int

        public var currentOutstanding: Int

        public var currentWaiters: Int

        @usableFromInline
        init() {
            self.acquisitions = 0
            self.releases = 0
            self.timeouts = 0
            self.cancellations = 0
            self.peakOutstanding = 0
            self.currentOutstanding = 0
            self.currentWaiters = 0
        }
    }
}
