#if !hasFeature(Embedded)

    extension Async.Broadcast {

        public struct Loss: Sendable {

            public let subscriberID: UInt64

            public let droppedCount: Int

            public let resumingAtIndex: UInt64

            public let reason: Reason

            @inlinable
            public init(
                subscriberID: UInt64,
                droppedCount: Int,
                resumingAtIndex: UInt64,
                reason: Reason
            ) {
                self.subscriberID = subscriberID
                self.droppedCount = droppedCount
                self.resumingAtIndex = resumingAtIndex
                self.reason = reason
            }
        }

    }

    extension Async.Broadcast.Loss {

        public enum Reason: Sendable, Equatable {

            case capacityLimit
        }
    }

#endif
