#if hasFeature(NonescapableTypes)
internal typealias AnyType = any (~Copyable & ~Escapable).Type
#else
internal typealias AnyType = any ~Copyable.Type
#endif

#if compiler(>=6.3)
@inline(always)
func _equalTypes(_ lhs: AnyType, _ rhs: AnyType) -> Bool { lhs == rhs }

@inline(always)
func _hashType(_ type: AnyType, into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(type))
}
#elseif compiler(>=6.2)
@inline(__always)
func _equalTypes(_ lhs: AnyType, _ rhs: AnyType) -> Bool { lhs == rhs }

@inline(__always)
func _hashType(_ type: AnyType, into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(type))
}
#else
@inline(__always)
func _equalTypes(_ lhs: AnyType, _ rhs: AnyType) -> Bool {
    if let lhsAny = lhs as? Any.Type, let rhsAny = rhs as? Any.Type {
        return lhsAny == rhsAny
    }
    let lhsPtr = unsafeBitCast(lhs, to: UnsafeRawPointer.self)
    let rhsPtr = unsafeBitCast(rhs, to: UnsafeRawPointer.self)
    return lhsPtr == rhsPtr
}

@inline(__always)
func _hashType(_ type: AnyType, into hasher: inout Hasher) {
    if let anyType = type as? Any.Type {
        hasher.combine(ObjectIdentifier(anyType))
    } else {
        hasher.combine(unsafeBitCast(type, to: UnsafeRawPointer.self))
    }
}
#endif
