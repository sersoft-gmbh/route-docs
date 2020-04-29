import Vapor
import Echo
import struct FFFoundation.TypeDescription

public struct EndpointDocumentation: Codable, Equatable {
    public struct Field: Codable, Equatable {
        public let name: String
        public let type: TypeDescription
        public let isOptional: Bool
    }

    public struct Object: Codable, Equatable {
        public let type: TypeDescription
        public let fields: [Field]
    }

    public struct Body: Codable, Equatable {
        public let mediaType: HTTPMediaType
        public let objects: [Object]
    }

    public let groupName: String?
    public let method: HTTPMethod
    public let path: String
    public let query: Object?
    public let body: Body?
    public let response: Body?
}
/*
extension EndpointDocumentation {
    public init(path: [PathComponent], groupName: String? = nil, query: Object? = nil, body: Body? = nil, response: Body? = nil) throws {
        precondition(!path.isEmpty)
        try self.init(groupName: groupName,
                      method: HTTPMethod(pathComponent: path[0]),
                      path: Array(path.dropFirst()).string,
                      query: query, body: body, response: response)
    }
}

extension EndpointDocumentation.Body {
    public init<T: Decodable>(object: T.Type, as mediaType: HTTPMediaType) throws {
        try self.init(mediaType: mediaType, objects: EndpointDocumentation.Object.objects(from: object))
    }

    @inlinable
    public init<T: Content>(object: T.Type) throws {
        try self.init(object: object, as: object.defaultContentType)
    }
}

extension EndpointDocumentation.Object {
    private static func subObjects<T: Decodable>(of object: T.Type,
                                                 atDepth depth: Int,
                                                 using decoded: [PartialKeyPath<T>]) throws -> [EndpointDocumentation.Object] {
        assert(depth > 0)
        let meta = reflect(object)
        switch meta.kind {
        case .class:
            let classMeta = meta as! ClassMetadata
        case .struct:
            let structMeta = meta as! StructMetadata
        case .enum, .optional:
            let enumMeta = meta as! EnumMetadata
        case .foreignClass:
            let concreteMeta = meta as! ForeignClassMetadata
        case .opaque:
            let opaqueMeta = meta as! OpaqueMetadata
        case .tuple:
            let tupleMeta = meta as! TupleMetadata
        case .function:
        case .existential:
        case .metatype:
        case .objcClassWrapper:
        case .existentialMetatype:
        case .heapLocalVariable:
        case .heapGenericLocalVariable:
        case .errorObject:
        }
        let levelDecoded = try object.decodeProperties(depth: depth)
        guard !levelDecoded.isEmpty else { return [] }
        return try Dictionary(grouping: levelDecoded.lazy,
                              by: { $0.path.prefix(upTo: depth) }).compactMap { element in
            decoded.first(where: { $0.path.prefix(upTo: depth) == element.key }).flatMap {
                self.init(type: $0.type, properties: element.value, atDepth: depth)
            }
        } + subObjects(of: object, atDepth: depth + 1, using: levelDecoded)
    }

    fileprivate static func objects<T: Decodable>(from object: T.Type) throws -> [EndpointDocumentation.Object] {
        let excluded = try properties.compactMap { try object.anyDecodeProperty(valueType: Swift.type(of: $0).valueType, keyPath: $0) }
        let decoded = try object.decodeProperties(depth: 0)
        return try CollectionOfOne(self.init(type: object, properties: decoded))
            + subObjects(of: object, atDepth: 1, using: decoded).reduce(into: []) { $0.appendIfNotExists($1) }
    }

    private init(type: Any.Type, properties: [ReflectedProperty], atDepth depth: Int = 0) {
        let actualType = (type as? AnyTypeWrapping.Type)?.leafType ?? type
        self.init(type: TypeDescription(any: actualType),
                  fields: properties.map { EndpointDocumentation.Field(reflected: $0, atDepth: depth) })
    }

    public init<T: Decodable>(object: T.Type) throws {
        let excluded = try properties.compactMap { try object.anyDecodeProperty(valueType: Swift.type(of: $0).valueType, keyPath: $0) }
        let decoded = try object.decodeProperties(depth: 0)
        self.init(type: object, properties: decoded)
    }

    @inlinable
    public init<T: Decodable>(object: T.Type, without properties: PartialKeyPath<T>...) throws {
        try self.init(object: object, without: properties)
    }
}

extension EndpointDocumentation.Field {
    fileprivate init(reflected property: ReflectedProperty, atDepth depth: Int) {
        let optionalCleanedType = (property.type as? AnyOptionalType.Type)?.anyWrappedType ?? property.type
        let dtoCleanedType = (optionalCleanedType as? AnyTypeWrapping.Type)?.leafType ?? optionalCleanedType
        self.init(name: property.path[depth],
                  type: TypeDescription(any: dtoCleanedType),
                  isOptional: (property.type is AnyOptionalType.Type))
    }
}

fileprivate extension RangeReplaceableCollection where Element: Equatable {
    mutating func appendIfNotExists(_ element: Element) {
        guard !contains(element) else { return }
        append(element)
    }
}
*/
