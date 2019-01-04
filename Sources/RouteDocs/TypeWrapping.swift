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
    static var leafType: Any.Type {
        return (wrappedType as? AnyTypeWrapping.Type)?.leafType ?? wrappedType
    }
}

// We detect optionals seperately, so we need to make them "transparent".
extension Optional: AnyTypeWrapping where Wrapped: AnyTypeWrapping {
    public static var wrappedType: Any.Type { return Wrapped.wrappedType }
}

// We detect optionals seperately, so we need to make them "transparent".
extension Optional: TypeWrapping where Wrapped: TypeWrapping {}
