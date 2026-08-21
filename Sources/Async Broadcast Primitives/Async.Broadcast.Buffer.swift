#if !hasFeature(Embedded)

    import Index_Primitives

    extension Async.Broadcast {

        struct Buffer {

            let limit: Index<(index: UInt64, element: Element)>.Count
        }
    }

#endif
