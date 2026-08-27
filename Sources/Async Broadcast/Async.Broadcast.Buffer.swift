#if !hasFeature(Embedded)

    import Index

    extension Async.Broadcast {

        struct Buffer {

            let limit: Index<(index: UInt64, element: Element)>.Count
        }
    }

#endif
