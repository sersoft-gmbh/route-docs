public protocol TypeWrapping<Wrapped> {
    associatedtype Wrapped
}

extension TypeWrapping {
    private static func leafType(history: Array<Any.Type>) -> Any.Type {
        let wrapped = Wrapped.self
        guard !history.contains(where: { $0 == wrapped }) else {
            // If the history contains our wrapped type already, we encountered a loop.
            // Loops aren't necessarily bad, we just need to detect them
            // and return the last element (which is us in this case).
            return self
        }
        return (wrapped as? any TypeWrapping.Type)?.leafType(history: history + CollectionOfOne<Any.Type>(self)) ?? wrapped
    }

    internal static var leafType: Any.Type { leafType(history: .init()) }
}

// We detect optionals seperately, so we need to make them "transparent".
extension Optional: TypeWrapping where Wrapped: TypeWrapping {}
