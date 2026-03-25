/*
 This code produces warnings, that are incorrect: https://github.com/swiftlang/swift/issues/88103
 */

#if hasFeature(NonescapableTypes)
fileprivate protocol AnyOptional: ~Copyable, ~Escapable {
    static var wrappedType: AnyType { get }
}

extension Optional: AnyOptional where Wrapped: ~Copyable, Wrapped: ~Escapable {
    static var wrappedType: AnyType { Wrapped.self }
}
#else
fileprivate protocol AnyOptional: ~Copyable, ~Escapable {
    static var wrappedType: AnyType { get }
}

extension Optional: AnyOptional where Wrapped: ~Copyable {
    static var wrappedType: AnyType { Wrapped.self }
}
#endif

func _isOptionalType(_ type: AnyType) -> Bool {
    type is any AnyOptional.Type
}

func _unwrapOptionals(in type: AnyType) -> AnyType {
#if hasFeature(NonescapableTypes)
    (type as? any (AnyOptional & ~Copyable & ~Escapable).Type).map { _unwrapOptionals(in: $0.wrappedType) } ?? type
#else
    (type as? any (AnyOptional & ~Copyable).Type).map { _openOptionals(in: $0.wrappedType) } ?? type
#endif
}
