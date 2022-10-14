import Vapor

public struct DocumentationType: Codable, Equatable, CustomStringConvertible, Sendable {
    public let typeDescription: TypeDescription
    public let customName: String?

    public var defaultName: String {
        customName ?? typeDescription.typeName(includingModule: true)
    }

    public var description: String { defaultName }

    init(_ type: Any.Type) {
        typeDescription = .init(any: type)
        customName = (type as? CustomDocumentationNamed.Type)?.documentationName
    }

    init<T>(_ type: T.Type) {
        typeDescription = .init(type)
        customName = (type as? CustomDocumentationNamed.Type)?.documentationName
    }

    init<T: CustomDocumentationNamed>(_ type: T.Type) {
        typeDescription = .init(type)
        customName = type.documentationName
    }
}

public struct EndpointDocumentation: Codable, Equatable, CustomStringConvertible, Sendable {
    public struct Object: Codable, Equatable, CustomStringConvertible, Sendable {
        public enum Body: Codable, Equatable, CustomStringConvertible, Sendable {
            private enum CodingKeys: String, CodingKey {
                case isEmpty, fields, cases
            }

            public struct Field: Codable, Equatable, CustomStringConvertible, Sendable {
                public let name: String
                public let type: DocumentationType
                public let isOptional: Bool

                public var description: String { "\(name): \(type)\(isOptional ? "?" : "")" }
            }

            public struct EnumCase: Codable, Equatable, CustomStringConvertible, Sendable {
                public let name: String?
                public let value: String

                public var description: String { "\(name.map { "\($0): " } ?? "")\(value)" }
            }

            case empty
            case fields(Array<Field>)
            case cases(Array<EnumCase>)

            public var description: String {
                switch self {
                case .empty: return "Empty"
                case .fields(let fields):
                    guard !fields.isEmpty else { return "Fields (empty)" }
                    return """
                    Fields {
                    \(fields
                        .sorted { $0.name < $1.name }
                        .map { "   \($0)" }
                        .joined(separator: "\n"))
                    }
                    """
                case .cases(let cases):
                    guard !cases.isEmpty else { return "Cases (empty)" }
                    return """
                    Cases {
                    \(cases
                        .sorted { $0.value < $1.value }
                        .map { "   - \($0)" }
                        .joined(separator: "\n"))
                    }
                    """
                }
            }

            public var isEmpty: Bool {
                switch self {
                case .empty: return true
                case .fields(let fields): return fields.isEmpty
                case .cases(let cases): return cases.isEmpty
                }
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                if try container.decode(Bool.self, forKey: .isEmpty) {
                    self = .empty
                } else if let fields = try container.decodeIfPresent(Array<Field>.self, forKey: .fields) {
                    self = .fields(fields)
                } else {
                    self = .cases(try container.decode(Array<EnumCase>.self, forKey: .cases))
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

            public func filter(fieldNames: Set<String>) -> Self {
                switch self {
                case .empty: return .empty
                case .fields(let fields): return .fields(fields.filter { !fieldNames.contains($0.name) })
                case .cases(let cases): return .cases(cases.filter { $0.name.map(fieldNames.contains) != true })
                }
            }

            @inlinable
            public func filter(fieldNames: String...) -> Self {
                filter(fieldNames: Set(fieldNames))
            }
        }

        public let type: DocumentationType
        public let body: Body

        public var description: String {
            guard !body.isEmpty else { return String(describing: type) }
            let fieldIndention = String(repeating: " ", count: 3)
            let bodyDesc: String
            switch body {
            case .empty: return String(describing: type)
            case .fields(let fields):
                bodyDesc = fields
                    .sorted { $0.name < $1.name }
                    .map { "\(fieldIndention)\($0)" }
                    .joined(separator: "\n")
            case .cases(let cases):
                bodyDesc = cases
                    .sorted { $0.value < $1.value }
                    .map { "\(fieldIndention)- \($0)" }
                    .joined(separator: "\n")
            }
            return "\(type) {\n\(bodyDesc)\n}"
        }

        public func adjustingBody(with closure: (inout Body) throws -> ()) rethrows -> Self {
            var newBody = body
            try closure(&newBody)
            return .init(type: type, body: newBody)
        }
    }

    public struct Payload: Codable, Equatable, CustomStringConvertible, @unchecked Sendable { // unchecked because of HTTPMediaType
        public let mediaType: HTTPMediaType
        public let objects: Array<Object>

        public var description: String {
            """
            <\(mediaType)>
            \(objects.map { String(describing: $0) }.joined(separator: "\n\n"))
            """
        }

        public func filterObjects(with closure: (Object) throws -> Object?) rethrows -> Self {
            try .init(mediaType: mediaType, objects: objects.compactMap(closure))
        }

        public func filterObjects(with closure: (Object) throws -> Bool) rethrows -> Self {
            try .init(mediaType: mediaType, objects: objects.filter(closure))
        }
    }

    public let groupName: String?
    public let method: HTTPMethod
    public let path: String
    public let query: Object?
    public let request: Payload?
    public let response: Payload?
    public let requiredAuthorization: Array<String>

    public var description: String {
        [
            groupName.map { "[\($0)]" },
            "\(method) \(path)",
            query.map { "Query:\n\($0)" },
            request.map { "Request:\n\($0)" },
            response.map { "Request:\n\($0)" },
            requiredAuthorization.isEmpty ? nil : "Required Authorization: " + requiredAuthorization.joined(separator: ", "),
        ].lazy.compactMap { $0 }.joined(separator: "\n")
    }
}

extension EndpointDocumentation {
    public init(method: HTTPMethod,
                path: Array<PathComponent>,
                groupName: String? = nil,
                query: Object? = nil,
                request: Payload? = nil,
                response: Payload? = nil,
                requiredAuthorization: Array<String> = .init()) {
        self.init(groupName: groupName, method: method, path: path.string,
                  query: query, request: request, response: response,
                  requiredAuthorization: requiredAuthorization)
    }
}

extension EndpointDocumentation.Payload {
    public init<T: Decodable>(object: T.Type,
                              as mediaType: HTTPMediaType,
                              customUserInfo: Dictionary<CodingUserInfoKey, Any> = .init()) throws {
        try self.init(mediaType: mediaType,
                      objects: EndpointDocumentation.Object.objects(from: object.reflectedDocumentation(withCustomUserInfo: customUserInfo)))
    }

    public init<T: CustomDocumentable>(object: T.Type, as mediaType: HTTPMediaType) throws {
        self.init(mediaType: mediaType,
                  objects: EndpointDocumentation.Object.objects(from: object.object(with: object)))
    }

    @inlinable
    public init<T: Content>(object: T.Type, customUserInfo: Dictionary<CodingUserInfoKey, Any> = .init()) throws {
        try self.init(object: object, as: object.defaultContentType, customUserInfo: customUserInfo)
    }

    @inlinable
    public init<T: Content & CustomDocumentable>(object: T.Type) throws {
        try self.init(object: object, as: object.defaultContentType)
    }
}

extension EndpointDocumentation.Object {
    fileprivate static func addObjects(from documentation: DocumentationObject,
                                       to list: inout Array<EndpointDocumentation.Object>) {
        list.appendIfNotExists(self.init(documentation: documentation))
        if case .fields(let fields) = documentation.body {
            fields.values.forEach { addObjects(from: $0, to: &list) }
        }
    }

    fileprivate static func objects(from documentation: DocumentationObject) -> Array<EndpointDocumentation.Object> {
        var list = Array<EndpointDocumentation.Object>()
        addObjects(from: documentation, to: &list)
        return list
    }

    private init(documentation: DocumentationObject) {
        let actualType = (documentation.type as? AnyTypeWrapping.Type)?.leafType ?? documentation.type
        self.init(type: DocumentationType(actualType), body: .init(documentation: documentation.body))
    }

    public init<T: Decodable>(object: T.Type, customUserInfo: Dictionary<CodingUserInfoKey, Any> = .init()) throws {
        try self.init(documentation: object.reflectedDocumentation(withCustomUserInfo: customUserInfo))
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
            self = .fields(fields.sorted { $0.key < $1.key }.map { Field(name: $0.key, documentation: $0.value) })
        case .cases(let cases):
            self = .cases(cases.sorted { ($0.name ?? "", $0.value) < ($1.name ?? "", $1.value) }.map(EnumCase.init))
        }
    }
}

extension EndpointDocumentation.Object.Body.Field {
    fileprivate init(name: String, documentation: DocumentationObject) {
        let optionalCleanedType = (documentation.type as? AnyOptionalType.Type)?.anyWrappedType ?? documentation.type
        let leafType = (optionalCleanedType as? AnyTypeWrapping.Type)?.leafType ?? optionalCleanedType
        self.init(name: name, type: DocumentationType(leafType), isOptional: documentation.isOptional)
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
