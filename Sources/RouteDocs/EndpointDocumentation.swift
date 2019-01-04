import Vapor
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
        public let mediaType: MediaType
        public let objects: [Object]
    }

    public let groupName: String?
    public let method: HTTPMethod
    public let path: String
    public let query: Object?
    public let body: Body?
    public let response: Body?
}

extension EndpointDocumentation {
    public init(path: [PathComponent], groupName: String? = nil, query: Object? = nil, body: Body? = nil, response: Body? = nil) throws {
        try self.init(groupName: groupName,
                      method: HTTPMethod(pathComponent: path[0]),
                      path: Array(path.dropFirst()).readable,
                      query: query, body: body, response: response)
    }
}

extension EndpointDocumentation.Body {
    public init<T: Decodable>(object: T.Type, as mediaType: MediaType, without properties: [PartialKeyPath<T>]) throws {
        try self.init(mediaType: mediaType,
                      objects: EndpointDocumentation.Object.objects(from: object, without: properties))
    }

    @inlinable
    public init<T: Decodable>(object: T.Type, as mediaType: MediaType, without properties: PartialKeyPath<T>...) throws {
        try self.init(object: object, as: mediaType, without: properties)
    }

    public init<T: Content>(object: T.Type, without properties: [PartialKeyPath<T>]) throws {
        try self.init(object: object, as: object.defaultContentType, without: properties)
    }

    @inlinable
    public init<T: Content>(object: T.Type, without properties: PartialKeyPath<T>...) throws {
        try self.init(object: object, without: properties)
    }

    @inlinable
    public init<T: TypeWrapping>(object: T.Type, as mediaType: MediaType, without properties: [PartialKeyPath<T.Wrapped>]) throws where T.Wrapped: Decodable {
        try self.init(object: object.Wrapped.self, as: mediaType, without: properties)
    }

    @inlinable
    public init<T: TypeWrapping>(object: T.Type, as mediaType: MediaType, without properties: PartialKeyPath<T.Wrapped>...) throws where T.Wrapped: Decodable {
        try self.init(object: object, as: mediaType, without: properties)
    }

    @inlinable
    public init<T: TypeWrapping>(object: T.Type, without properties: [PartialKeyPath<T.Wrapped>]) throws where T.Wrapped: Content {
        try self.init(object: object.Wrapped.self, without: properties)
    }

    @inlinable
    public init<T: TypeWrapping>(object: T.Type, without properties: PartialKeyPath<T.Wrapped>...) throws where T.Wrapped: Content {
        try self.init(object: object, without: properties)
    }
}

extension EndpointDocumentation.Object {
    private static func subObjects<T: Decodable>(of object: T.Type,
                                                 atDepth depth: Int,
                                                 using decoded: [ReflectedProperty],
                                                 without excluded: [ReflectedProperty]) throws -> [EndpointDocumentation.Object] {
        assert(depth > 0, "Depth must be greater than 0")
        let levelDecoded = try object.decodeProperties(depth: depth)
        guard !levelDecoded.isEmpty else { return [] }
        return try Dictionary(grouping: levelDecoded.filter(excluded: excluded),
                              by: { $0.path.prefix(upTo: depth) }).compactMap { element in
            decoded.first(where: { $0.path.prefix(upTo: depth) == element.key }).flatMap {
                self.init(type: $0.type, properties: element.value, atDepth: depth)
            }
        } + subObjects(of: object, atDepth: depth + 1, using: levelDecoded, without: excluded)
    }

    fileprivate static func objects<T: Decodable>(from object: T.Type, without properties: [PartialKeyPath<T>]) throws -> [EndpointDocumentation.Object] {
        let excluded = try properties.compactMap { try object.anyDecodeProperty(valueType: Swift.type(of: $0).valueType, keyPath: $0) }
        let decoded = try object.decodeProperties(depth: 0)
        return try [self.init(type: object, properties: decoded.filter(excluded: excluded))]
            + subObjects(of: object, atDepth: 1, using: decoded, without: excluded).reduce(into: []) { $0.appendIfNotExists($1) }
    }

    private init(type: Any.Type, properties: [ReflectedProperty], atDepth depth: Int = 0) {
        let actualType = (type as? AnyTypeWrapping.Type)?.leafType ?? type
        self.init(type: TypeDescription(any: actualType),
                  fields: properties.map { EndpointDocumentation.Field(reflected: $0, atDepth: depth) })
    }

    public init<T: Decodable>(object: T.Type, without properties: [PartialKeyPath<T>]) throws {
        let excluded = try properties.compactMap { try object.anyDecodeProperty(valueType: Swift.type(of: $0).valueType, keyPath: $0) }
        let decoded = try object.decodeProperties(depth: 0)
        self.init(type: object, properties: decoded.filter(excluded: excluded))
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

fileprivate extension Collection where Element == ReflectedProperty {
    func filter<C: Collection>(excluded: C) -> [Element] where C.Element == Element {
        return filter { p in !excluded.contains { $0.path == p.path } }
    }
}

fileprivate extension RangeReplaceableCollection where Element: Equatable {
    mutating func appendIfNotExists(_ element: Element) {
        guard !contains(element) else { return }
        append(element)
    }
}
