import Vapor
import struct FFFoundation.TypeDescription

public struct EndpointDocumentation: Codable, Equatable {
    public struct Object: Codable, Equatable {
        public enum Body: Codable, Equatable {
            private enum CodingKeys: String, CodingKey {
                case isEmpty, fields, cases
            }

            public struct Field: Codable, Equatable {
                public let name: String
                public let type: TypeDescription
                public let isOptional: Bool
            }

            public struct EnumCase: Codable, Equatable {
                public let name: String?
                public let value: String
            }

            case empty
            case fields([Field])
            case cases([EnumCase])

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                if try container.decode(Bool.self, forKey: .isEmpty) {
                    self = .empty
                } else if let fields = try container.decodeIfPresent([Field].self, forKey: .fields) {
                    self = .fields(fields)
                } else {
                    self = .cases(try container.decode([EnumCase].self, forKey: .cases))
                }
            }

            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                switch self {
                case .empty:
                    try container.encode(true, forKey: .isEmpty)
                    try container.encodeNil(forKey: .fields)
                    try container.encodeNil(forKey: .cases)
                case .fields(let fields):
                    try container.encode(fields.isEmpty, forKey: .isEmpty)
                    try container.encode(fields, forKey: .fields)
                    try container.encodeNil(forKey: .cases)
                case .cases(let cases):
                    try container.encode(cases.isEmpty, forKey: .isEmpty)
                    try container.encodeNil(forKey: .fields)
                    try container.encode(cases, forKey: .cases)
                }
            }
        }

        public let type: TypeDescription
        public let body: Body
    }

    public struct Payload: Codable, Equatable {
        public let mediaType: HTTPMediaType
        public let objects: [Object]
    }

    public let groupName: String?
    public let method: HTTPMethod
    public let path: String
    public let query: Object?
    public let request: Payload?
    public let response: Payload?
}

extension EndpointDocumentation {
    public init(path: [PathComponent], groupName: String? = nil, query: Object? = nil, request: Payload? = nil, response: Payload? = nil) throws {
        precondition(!path.isEmpty)
        try self.init(groupName: groupName,
                      method: HTTPMethod(pathComponent: path[0]),
                      path: Array(path.dropFirst()).string,
                      query: query, request: request, response: response)
    }
}

extension EndpointDocumentation.Payload {
    public init<T: Decodable>(object: T.Type, as mediaType: HTTPMediaType) throws {
        try self.init(mediaType: mediaType,
                      objects: EndpointDocumentation.Object.objects(from: object.reflectedDocumentation()))
    }

    public init<T: CustomDocumentable>(object: T.Type, as mediaType: HTTPMediaType) throws {
        self.init(mediaType: mediaType,
                  objects: EndpointDocumentation.Object.objects(from: object.object(with: object)))
    }

    @inlinable
    public init<T: Content>(object: T.Type) throws {
        try self.init(object: object, as: object.defaultContentType)
    }
}

extension EndpointDocumentation.Object {
    private static func subObjects(in body: DocumentationObject.Body) -> [EndpointDocumentation.Object] {
        switch body {
        case .none, .cases(_): return []
        case .fields(let fields): return fields.values.flatMap(objects)
        }
    }

    fileprivate static func objects(from documentation: DocumentationObject) -> [EndpointDocumentation.Object] {
        CollectionOfOne(self.init(documentation: documentation))
            + subObjects(in: documentation.body).reduce(into: []) { $0.appendIfNotExists($1) }
    }

    private init(documentation: DocumentationObject) {
        let actualType = (documentation.type as? AnyTypeWrapping.Type)?.leafType ?? documentation.type
        self.init(type: TypeDescription(any: actualType),
                  body: .init(documentation: documentation.body))
    }

    public init<T: Decodable>(object: T.Type) throws {
        try self.init(documentation: object.reflectedDocumentation())
    }

    public init<T: CustomDocumentable>(object: T.Type) {
        self.init(documentation: object.object(with: object))
    }
}

extension EndpointDocumentation.Object.Body {
    fileprivate init(documentation: DocumentationObject.Body) {
        switch documentation {
        case .none: self = .empty
        case .fields(let fields):
            self = .fields(fields.sorted(by: { $0.key < $1.key }).map { Field(name: $0.key, documentation: $0.value) })
        case .cases(let cases):
            self = .cases(cases.sorted(by: { $0.name ?? ""  < $1.name ?? "" && $0.value < $1.value }).map(EnumCase.init))
        }
    }
}

extension EndpointDocumentation.Object.Body.Field {
    fileprivate init(name: String, documentation: DocumentationObject) {
        let optionalCleanedType = (documentation.type as? AnyOptionalType.Type)?.anyWrappedType ?? documentation.type
        let dtoCleanedType = (optionalCleanedType as? AnyTypeWrapping.Type)?.leafType ?? optionalCleanedType
        self.init(name: name,
                  type: TypeDescription(any: dtoCleanedType),
                  isOptional: documentation.isOptional)
    }
}

extension EndpointDocumentation.Object.Body.EnumCase {
    fileprivate init(documentation: DocumentationObject.Body.EnumCase) {
        self.init(name: documentation.name, value: documentation.value)
    }
}

fileprivate extension RangeReplaceableCollection where Element: Equatable {
    mutating func appendIfNotExists(_ element: Element) {
        guard !contains(element) else { return }
        append(element)
    }
}
