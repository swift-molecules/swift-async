#if !hasFeature(Embedded)

    extension Async {

        public struct Channel<Element: ~Copyable> {}
    }

#endif
