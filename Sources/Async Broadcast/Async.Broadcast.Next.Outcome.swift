#if !hasFeature(Embedded)

    extension Async.Broadcast.Next {

        enum Outcome {

            case element(Element)

            case finished

            case cancelled
        }
    }

#endif
