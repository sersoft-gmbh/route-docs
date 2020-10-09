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

extension Array: CustomDocumentationNamed where Element: CustomDocumentationNamed {
    public static var documentationName: String { "Array<\(Element.documentationName)>" }
}

extension ContiguousArray: CustomDocumentationNamed where Element: CustomDocumentationNamed {
    public static var documentationName: String { "ContiguousArray<\(Element.documentationName)>" }
}

extension Set: CustomDocumentationNamed where Element: CustomDocumentationNamed {
    public static var documentationName: String { "Set<\(Element.documentationName)>" }
}

extension Range: CustomDocumentationNamed where Bound: CustomDocumentationNamed {
    public static var documentationName: String { "Range<\(Bound.documentationName)>" }
}

extension ClosedRange: CustomDocumentationNamed where Bound: CustomDocumentationNamed {
    public static var documentationName: String { "ClosedRange<\(Bound.documentationName)>" }
}

extension PartialRangeFrom: CustomDocumentationNamed where Bound: CustomDocumentationNamed {
    public static var documentationName: String { "PartialRangeFrom<\(Bound.documentationName)>" }
}

extension PartialRangeUpTo: CustomDocumentationNamed where Bound: CustomDocumentationNamed {
    public static var documentationName: String { "PartialRangeUpTo<\(Bound.documentationName)>" }
}

extension PartialRangeThrough: CustomDocumentationNamed where Bound: CustomDocumentationNamed {
    public static var documentationName: String { "PartialRangeThrough<\(Bound.documentationName)>" }
}
