import Foundation

extension Date: CustomDocumentable {
    @inlinable
    public static var documentationInstance: Date { .init() }

    @inlinable
    public static var documentationBody: DocumentationObject.Body { .none }
}

extension UUID: CustomDocumentable {
    @inlinable
    public static var documentationInstance: UUID { .init() }

    @inlinable
    public static var documentationBody: DocumentationObject.Body { .none }
}

extension CaseIterable where Self: RawRepresentable {
    @usableFromInline
    static var allCasesDocumentationBody: DocumentationObject.Body {
        .cases(allCases.map(DocumentationObject.Body.EnumCase.init))
    }
}

extension CaseIterable where Self: RawRepresentable, Self: CustomDocumentable {
    @inlinable
    public static var documentationBody: DocumentationObject.Body { allCasesDocumentationBody }
}
