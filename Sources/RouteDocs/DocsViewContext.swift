import Vapor
import struct FFFoundation.TypeDescription

/// This can be used as context for a Documentation view.
public struct DocsViewContext: Encodable {
    public struct Documentation: Encodable {
        public struct Object: Encodable {
            public enum Body: Encodable {
                private enum CodingKeys: String, CodingKey {
                    case isEmpty, fields, cases
                }

                public struct Field: Encodable {
                    public let name: String
                    public let type: String
                    public let isOptional: Bool
                }
                public struct EnumCase: Encodable {
                    public let name: String?
                    public let value: String
                }

                case empty
                case fields([Field])
                case cases([EnumCase])

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
            public let name: String
            public let body: Body
        }

        public struct Payload: Encodable {
            public let mediaType: HTTPMediaType
            public let objects: [Object]
        }

        public let method: HTTPMethod
        public let path: String
        public let query: Object?
        public let request: Payload?
        public let response: Payload?
    }

    public struct GroupedDocumentation: Encodable {
        public let groupName: String
        public let documentations: [Documentation]
    }

    public let groupedDocumentations: [GroupedDocumentation]
    public let otherDocumentations: [Documentation]
}

fileprivate extension HTTPMethod {
    var sortOrder: String {
        switch self {
        case .GET: return "1GET"
        case .PUT: return "2PUT"
        case .POST: return "3POST"
        case .DELETE: return "4DELETE"
        default: return string
        }
    }
}

fileprivate extension DocumentationType {
    func docsTypeName(using namePath: KeyPath<DocumentationType, String>?) -> String {
        namePath.map { self[keyPath: $0] } ?? typeDescription.typeName(includingModule: false)
    }
}

fileprivate extension EndpointDocumentation {
    var sortOrder: String { method.sortOrder + "/" + path }
}

extension DocsViewContext.Documentation.Object.Body.EnumCase {
    public init(enumCase: EndpointDocumentation.Object.Body.EnumCase) {
        self.init(name: enumCase.name, value: enumCase.value)
    }
}

extension DocsViewContext.Documentation.Object.Body.Field {
    public init(field: EndpointDocumentation.Object.Body.Field, usingName namePath: KeyPath<DocumentationType, String>? = nil) {
        self.init(name: field.name,
                  type: field.type.docsTypeName(using: namePath),
                  isOptional: field.isOptional)
    }
}

extension DocsViewContext.Documentation.Object.Body {
    @inlinable
    public init(body: EndpointDocumentation.Object.Body, usingName namePath: KeyPath<DocumentationType, String>? = nil) {
        switch body {
        case .empty: self = .empty
        case .fields(let fields): self = .fields(fields.map { .init(field: $0, usingName: namePath) })
        case .cases(let cases): self = .cases(cases.map(EnumCase.init))
        }
    }
}

extension DocsViewContext.Documentation.Object {
    public init(object: EndpointDocumentation.Object, usingName namePath: KeyPath<DocumentationType, String>? = nil) {
        self.init(name: object.type.docsTypeName(using: namePath),
                  body: .init(body: object.body, usingName: namePath))
    }
}

extension DocsViewContext.Documentation.Payload {
    public init(payload: EndpointDocumentation.Payload, usingName namePath: KeyPath<DocumentationType, String>? = nil) {
        self.init(mediaType: payload.mediaType,
                  objects: payload.objects.map { .init(object: $0, usingName: namePath) })
    }
}

extension DocsViewContext.Documentation {
    public init(documentation: EndpointDocumentation, usingName namePath: KeyPath<DocumentationType, String>? = nil) {
        self.init(method: documentation.method,
                  path: documentation.path,
                  query: documentation.query.map { .init(object: $0, usingName: namePath) },
                  request: documentation.request.map { .init(payload: $0, usingName: namePath) },
                  response: documentation.response.map { .init(payload: $0, usingName: namePath) })
    }
}

fileprivate extension Sequence where Element == EndpointDocumentation {
    func contextDocumentation<C: Comparable>(orderedBy keyPath: KeyPath<Element, C>,
                                             usingName namePath: KeyPath<DocumentationType, String>?) -> [DocsViewContext.Documentation] {
        sorted { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
            .map { DocsViewContext.Documentation(documentation: $0, usingName: namePath) }
    }
}

extension DocsViewContext {
    public init<Docs: Sequence, C: Comparable>(documentables: Docs,
                                               sortedBy sortPath: KeyPath<EndpointDocumentation, C>,
                                               usingName namePath: KeyPath<DocumentationType, String>? = nil)
        where Docs.Element == EndpointDocumentable
    {
        let allDocsByGroup = Dictionary(grouping: documentables.lazy.compactMap(\.documentation), by: { $0.groupName ?? "" })
        otherDocumentations = allDocsByGroup["", default: []].lazy.contextDocumentation(orderedBy: sortPath, usingName: namePath)
        groupedDocumentations = allDocsByGroup.lazy
            .filter { !$0.key.isEmpty }
            .map { DocsViewContext.GroupedDocumentation(groupName: $0.key,
                                                    documentations: $0.value.contextDocumentation(orderedBy: sortPath, usingName: namePath)) }
            .sorted { $0.groupName < $1.groupName }
    }

    public init<Docs: Sequence>(documentables: Docs, usingName namePath: KeyPath<DocumentationType, String>? = nil)
        where Docs.Element == EndpointDocumentable
    {
        self.init(documentables: documentables, sortedBy: \.sortOrder, usingName: namePath)
    }

    @inlinable
    public init<C: Comparable>(routes: Routes, sortedBy sortPath: KeyPath<EndpointDocumentation, C>,
                               usingName namePath: KeyPath<DocumentationType, String>? = nil) {
        self.init(documentables: routes.all, sortedBy: sortPath, usingName: namePath)
    }

    public init(routes: Routes, usingName namePath: KeyPath<DocumentationType, String>? = nil) {
        self.init(documentables: routes.all, sortedBy: \.sortOrder, usingName: namePath)
    }
}
