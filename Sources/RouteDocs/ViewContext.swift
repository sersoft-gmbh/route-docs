import Vapor
import struct FFFoundation.TypeDescription

/// This can be used as context for a Documentation view.
public struct ViewContext: Encodable {
    public struct Documentation: Encodable {
        public struct Field: Encodable {
            public let name: String
            public let type: String
            public let isOptional: Bool
        }

        public struct Object: Encodable {
            public let name: String
            public let fields: [Field]
        }

        public struct Body: Encodable {
            public let mediaType: MediaType
            public let objects: [Object]
        }

        public let method: HTTPMethod
        public let path: String
        public let query: Object?
        public let body: Body?
        public let response: Body?
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

fileprivate extension TypeDescription {
    func docsTypeName(using namePath: KeyPath<TypeDescription, String>?) -> String {
        return namePath.map { self[keyPath: $0] } ?? typeName(includingModule: false)
    }
}

fileprivate extension EndpointDocumentation {
    var sortOrder: String { return method.sortOrder + "/" + path }
}

extension ViewContext.Documentation.Field {
    public init(field: EndpointDocumentation.Field, usingName namePath: KeyPath<TypeDescription, String>? = nil) {
        self.init(name: field.name,
                  type: field.type.docsTypeName(using: namePath),
                  isOptional: field.isOptional)
    }
}

extension ViewContext.Documentation.Object {
    public init(object: EndpointDocumentation.Object, usingName namePath: KeyPath<TypeDescription, String>? = nil) {
        self.init(name: object.type.docsTypeName(using: namePath),
                  fields: object.fields.map { .init(field: $0, usingName: namePath) })
    }
}

extension ViewContext.Documentation.Body {
    public init(body: EndpointDocumentation.Body, usingName namePath: KeyPath<TypeDescription, String>? = nil) {
        self.init(mediaType: body.mediaType,
                  objects: body.objects.map { .init(object: $0, usingName: namePath) })
    }
}

extension ViewContext.Documentation {
    public init(documentation: EndpointDocumentation, usingName namePath: KeyPath<TypeDescription, String>? = nil) {
        self.init(method: documentation.method,
                  path: documentation.path,
                  query: documentation.query.map { Object(object: $0, usingName: namePath) },
                  body: documentation.body.map { .init(body: $0, usingName: namePath) },
                  response: documentation.response.map { .init(body: $0, usingName: namePath) })
    }
}

fileprivate extension Sequence where Element == EndpointDocumentation {
    func contextDocumentation<C: Comparable>(orderedBy keyPath: KeyPath<Element, C>, usingName namePath: KeyPath<TypeDescription, String>?) -> [ViewContext.Documentation] {
        return sorted { $0[keyPath: keyPath] < $1[keyPath: keyPath] }.map { ViewContext.Documentation(documentation: $0, usingName: namePath) }
    }
}

public extension ViewContext {
    public init<Docs: Sequence, C: Comparable>(documentables: Docs,
                                               sortedBy sortPath: KeyPath<EndpointDocumentation, C>,
                                               usingName namePath: KeyPath<TypeDescription, String>? = nil)
        where Docs.Element == EndpointDocumentable
    {
        let allDocsByGroup = Dictionary(grouping: documentables.lazy.compactMap { $0.documentation }, by: { $0.groupName ?? "" }) // TODO: Swift 4.2: Optional is Hashable
        otherDocumentations = allDocsByGroup["", default: []].lazy.contextDocumentation(orderedBy: sortPath, usingName: namePath)
        groupedDocumentations = allDocsByGroup.lazy
            .filter { !$0.key.isEmpty }
            .map { ViewContext.GroupedDocumentation(groupName: $0.key,
                                                    documentations: $0.value.contextDocumentation(orderedBy: sortPath, usingName: namePath)) }
            .sorted { $0.groupName < $1.groupName }
    }

    public init<Docs: Sequence>(documentables: Docs,
                                usingName namePath: KeyPath<TypeDescription, String>? = nil) where Docs.Element == EndpointDocumentable {
        self.init(documentables: documentables, sortedBy: \.sortOrder, usingName: namePath)
    }

    @inlinable
    public init<C: Comparable>(router: Router, sortedBy sortPath: KeyPath<EndpointDocumentation, C>, usingName namePath: KeyPath<TypeDescription, String>? = nil) {
        self.init(documentables: router.routes, sortedBy: sortPath, usingName: namePath)
    }
}
