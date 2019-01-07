public protocol AnyTypeWrapping {
    static var wrappedType: Any.Type { get }
}

public protocol TypeWrapping: AnyTypeWrapping {
    associatedtype Wrapped
}

extension TypeWrapping {
    public static var wrappedType: Any.Type { return Wrapped.self }
}

internal extension AnyTypeWrapping {
    private static func leafType(history: [Any.Type]) -> Any.Type {
        let wrapped = wrappedType
        if history.contains(where: { $0 == wrapped }) {
            // If the history contains our wrapped type already, we encountered a loop.
            // Loops aren't necessarily bad, we just need to detect them
            // and return the last element (which is us in this case).
            return self
        }
        return (wrapped as? AnyTypeWrapping.Type)?.leafType(history: history + [self]) ?? wrapped
    }

    static var leafType: Any.Type { return leafType(history: []) }
}

// We detect optionals seperately, so we need to make them "transparent".
extension Optional: AnyTypeWrapping where Wrapped: AnyTypeWrapping {
    public static var wrappedType: Any.Type { return Wrapped.wrappedType }
}

// We detect optionals seperately, so we need to make them "transparent".
extension Optional: TypeWrapping where Wrapped: TypeWrapping {}
