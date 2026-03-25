#if hasFeature(NonescapableTypes)
internal typealias AnyType = any (~Copyable & ~Escapable).Type
#else
internal typealias AnyType = any ~Copyable.Type
#endif
