#if hasFeature(NonescapableTypes)
public protocol TypeWrapping<Wrapped>: ~Copyable, ~Escapable {
    associatedtype Wrapped
}
fileprivate typealias TypeWrappingType = any (TypeWrapping & ~Copyable & ~Escapable).Type

fileprivate extension TypeWrapping where Self: ~Copyable, Self: ~Escapable {
    static var _wrappedType: AnyType { Wrapped.self }
}
#else
public protocol TypeWrapping<Wrapped>: ~Copyable {
    associatedtype Wrapped
}

fileprivate extension TypeWrapping where Self: ~Copyable {
    static var _wrappedType: AnyType { Wrapped.self }
}
fileprivate typealias TypeWrappingType = any (TypeWrapping & ~Copyable).Type
#endif

// We detect optionals seperately, so we need to make them "transparent".
extension Optional: TypeWrapping where Wrapped: TypeWrapping/*, Wrapped: ~Copyable*/ {}

fileprivate func leafType(of wrapping: TypeWrappingType, history: Array<AnyType>) -> AnyType {
    let wrapped = wrapping._wrappedType
    guard !history.contains(where: { _equalTypes($0, wrapped) }) else {
        // If the history contains our wrapped type already, we encountered a loop.
        // Loops aren't necessarily bad, we just need to detect them
        // and return the last element (which is us in this case).
        return wrapping
    }
    return leafTypeOrType(of: wrapped, history: history + CollectionOfOne<AnyType>(wrapping))
}

#if compiler(>=6.3)
@inline(always)
fileprivate func leafTypeOrType(of type: AnyType, history: @autoclosure () -> Array<AnyType>) -> AnyType {
    guard let wrapping = type as? TypeWrappingType else { return type }
    return leafType(of: wrapping, history: history())
}
#else
@inline(__always)
fileprivate func leafTypeOrType(of type: AnyType, history: @autoclosure () -> Array<AnyType>) -> AnyType {
    guard let wrapping = type as? TypeWrappingType else { return type }
    return leafType(of: wrapping, history: history())
}
#endif

func _leafType(of type: AnyType) -> AnyType {
    leafTypeOrType(of: type, history: [])
}
