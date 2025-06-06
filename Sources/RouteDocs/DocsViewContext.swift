public import Vapor

/// This can be used as context for a documentation view.
public struct DocsViewContext: Sendable, Encodable {
    public struct Documentation: Sendable, Encodable {
        public struct Object: Sendable, Encodable {
            public enum Body: Sendable, Encodable {
                private enum CodingKeys: String, CodingKey {
                    case isEmpty, fields, cases
                }

                public struct Field: Sendable, Encodable {
                    public let name: String
                    public let type: String
                    public let isOptional: Bool
                }

                public struct EnumCase: Sendable, Encodable {
                    public let name: String?
                    public let value: String
                }

                case empty
                case fields(Array<Field>)
                case cases(Array<EnumCase>)

                public func encode(to encoder: any Encoder) throws {
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

            public let name: String
            public let body: Body
        }

        public struct Query: Sendable, Encodable {
            public let objects: Array<Object>
        }

        public struct Payload: Encodable, @unchecked Sendable { // unchecked because of HTTPMediaType
            public let mediaType: HTTPMediaType
            public let objects: Array<Object>
        }

        public let method: HTTPMethod
        public let path: String
        public let query: Query?
        public let request: Payload?
        public let response: Payload?
        public let requiredAuthorization: Array<String>
    }

    public struct GroupedDocumentation: Sendable, Encodable {
        public let id: Int
        public let groupName: String
        public let documentations: Array<Documentation>
    }

    public let groupedDocumentations: Array<GroupedDocumentation>
    public let otherDocumentations: Array<Documentation>
}

extension HTTPMethod {
    fileprivate var sortOrder: String {
        switch self {
        case .GET: return "1GET"
        case .PUT: return "2PUT"
        case .POST: return "3POST"
        case .DELETE: return "4DELETE"
        default: return rawValue
        }
    }
}

extension DocumentationType {
    fileprivate func docsTypeName(using namePath: KeyPath<DocumentationType, String>?) -> String {
        customName ?? namePath.map { self[keyPath: $0] } ?? typeDescription.typeName(with: [.withParents])
    }
}

extension EndpointDocumentation {
    public var defaultSortOrder: some Comparable { method.sortOrder + "/" + path }
}

extension DocsViewContext.Documentation.Object.Body.EnumCase {
    public init(enumCase: EndpointDocumentation.Object.Body.EnumCase) {
        self.init(name: enumCase.name, value: enumCase.value)
    }
}

extension DocsViewContext.Documentation.Object.Body.Field {
    public init(field: EndpointDocumentation.Object.Body.Field,
                usingName namePath: KeyPath<DocumentationType, String>? = nil) {
        self.init(name: field.name,
                  type: field.type.docsTypeName(using: namePath),
                  isOptional: field.isOptional)
    }
}

extension DocsViewContext.Documentation.Object.Body {
    @inlinable
    public init(body: EndpointDocumentation.Object.Body,
                usingName namePath: KeyPath<DocumentationType, String>? = nil) {
        switch body {
        case .empty: self = .empty
        case .fields(let fields): self = .fields(fields.map { .init(field: $0, usingName: namePath) })
        case .cases(let cases): self = .cases(cases.map(EnumCase.init))
        }
    }
}

extension DocsViewContext.Documentation.Object {
    public init(object: EndpointDocumentation.Object,
                usingName namePath: KeyPath<DocumentationType, String>? = nil) {
        self.init(name: object.type.docsTypeName(using: namePath),
                  body: .init(body: object.body, usingName: namePath))
    }
}

extension DocsViewContext.Documentation.Query {
    public init(query: EndpointDocumentation.Query,
                usingName namePath: KeyPath<DocumentationType, String>? = nil) {
        self.init(objects: query.objects.map { .init(object: $0, usingName: namePath) })
    }
}

extension DocsViewContext.Documentation.Payload {
    public init(payload: EndpointDocumentation.Payload,
                usingName namePath: KeyPath<DocumentationType, String>? = nil) {
        self.init(mediaType: payload.mediaType,
                  objects: payload.objects.map { .init(object: $0, usingName: namePath) })
    }
}

extension DocsViewContext.Documentation {
    public init(documentation: EndpointDocumentation,
                usingName namePath: KeyPath<DocumentationType, String>? = nil) {
        self.init(method: documentation.method,
                  path: documentation.path,
                  query: documentation.query.map { .init(query: $0, usingName: namePath) },
                  request: documentation.request.map { .init(payload: $0, usingName: namePath) },
                  response: documentation.response.map { .init(payload: $0, usingName: namePath) },
                  requiredAuthorization: documentation.requiredAuthorization)
    }
}

extension Sequence where Element == EndpointDocumentation {
    fileprivate func contextDocumentation(orderedBy keyPath: KeyPath<Element, some Comparable>,
                              usingName namePath: KeyPath<DocumentationType, String>?) -> Array<DocsViewContext.Documentation> {
        sorted { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
            .map { DocsViewContext.Documentation(documentation: $0, usingName: namePath) }
    }
}

extension DocsViewContext {
    public init(documentables: some Sequence<any EndpointDocumentable>,
                sortedBy sortPath: KeyPath<EndpointDocumentation, some Comparable> = \.defaultSortOrder,
                usingName namePath: KeyPath<DocumentationType, String>? = nil) {
        let allDocsByGroup = Dictionary(grouping: documentables.lazy.compactMap(\.documentation), by: \.groupName)
        otherDocumentations = allDocsByGroup[nil, default: []].lazy.contextDocumentation(orderedBy: sortPath, usingName: namePath)
        groupedDocumentations = allDocsByGroup.lazy
            .compactMap { (key, elem) in key.map { (key: $0, value: elem) } }
            .sorted { $0.key < $1.key }
            .enumerated()
            .map { GroupedDocumentation(id: $0.offset,
                                        groupName: $0.element.key,
                                        documentations: $0.element.value.contextDocumentation(orderedBy: sortPath, usingName: namePath)) }
    }

    @inlinable
    public init(routes: Routes,
                sortedBy sortPath: KeyPath<EndpointDocumentation, some Comparable> = \.defaultSortOrder,
                usingName namePath: KeyPath<DocumentationType, String>? = nil) {
        self.init(documentables: routes.all, sortedBy: sortPath, usingName: namePath)
    }
}
