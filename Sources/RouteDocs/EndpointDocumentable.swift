import Vapor

public protocol EndpointDocumentable {
    var documentation: EndpointDocumentation? { get }
}

extension EndpointDocumentable where Self: Extendable {
    public fileprivate(set) var documentation: EndpointDocumentation? {
        get { extend.get("endpoint_documentation", default: nil) }
        nonmutating set { extend.set("endpoint_documentation", to: newValue) }
    }
}

extension Route: EndpointDocumentable {
    public private(set) var documentation: EndpointDocumentation? {
        get { userInfo["endpoint_documentation"] as? EndpointDocumentation }
        set { userInfo["endpoint_documentation"] = newValue }
    }

    public func addDocumentation(_ documentation: EndpointDocumentation) {
        self.documentation = documentation
    }

    @inlinable
    public func addDocumentation(groupedAs groupName: String? = nil,
                                 query: EndpointDocumentation.Object? = nil,
                                 body: EndpointDocumentation.Body? = nil,
                                 response: EndpointDocumentation.Body? = nil) throws {
//        try addDocumentation(EndpointDocumentation(path: path, groupName: groupName, query: query, body: body, response: response))
    }
}
