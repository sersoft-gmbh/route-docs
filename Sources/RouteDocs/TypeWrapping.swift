public protocol AnyTypeWrapping {
    static var wrappedType: Any.Type { get }
}

#if compiler(>=5.7)
public protocol TypeWrapping<Wrapped>: AnyTypeWrapping {
    associatedtype Wrapped
}
#else
public protocol TypeWrapping: AnyTypeWrapping {
    associatedtype Wrapped
}
#endif

extension TypeWrapping {
    @inlinable
    public static var wrappedType: Any.Type { Wrapped.self }
}

extension AnyTypeWrapping {
    private static func leafType(history: Array<Any.Type>) -> Any.Type {
        let wrapped = wrappedType
        guard !history.contains(where: { $0 == wrapped }) else {
            // If the history contains our wrapped type already, we encountered a loop.
            // Loops aren't necessarily bad, we just need to detect them
            // and return the last element (which is us in this case).
            return self
        }
        return (wrapped as? AnyTypeWrapping.Type)?.leafType(history: history + CollectionOfOne<Any.Type>(self)) ?? wrapped
    }

    internal static var leafType: Any.Type { leafType(history: []) }
}

// We detect optionals seperately, so we need to make them "transparent".
extension Optional: AnyTypeWrapping where Wrapped: AnyTypeWrapping {
    @inlinable
    public static var wrappedType: Any.Type { Wrapped.wrappedType }
}
extension Optional: TypeWrapping where Wrapped: TypeWrapping {}
