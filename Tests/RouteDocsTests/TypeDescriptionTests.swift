import XCTest
@testable import RouteDocs

extension Dictionary {
    enum SomeNestedType {}
    fileprivate enum SomeOtherNestedType {}
}

final class TypeDescriptionTests: XCTestCase {
    func testVariousTypes() {
        let typeDesc1 = TypeDescription(Dictionary<String, Dictionary<String, Int>.SomeNestedType>.Index.self)
        let typeDesc2 = TypeDescription(Dictionary<String, Dictionary<String, Int>.Index>.SomeOtherNestedType.self)
        let expected1 = TypeDescription(
            module: "Swift",
            parent: .init(
                module: "Swift",
                parent: nil,
                name: "Dictionary",
                genericParameters: [
                    .init(module: "Swift", parent: nil, name: "String", genericParameters: []),
                    .init(
                        module: "RouteDocsTests",
                        parent: .init(module: "Swift", parent: nil, name: "Dictionary", genericParameters: [
                            .init(module: "Swift", parent: nil, name: "String", genericParameters: []),
                            .init(module: "Swift", parent: nil, name: "Int", genericParameters: []),
                        ]),
                        name: "SomeNestedType",
                        genericParameters: []
                    ),
                ]
            ),
            name: "Index",
            genericParameters: []
        )
        let expected2 = TypeDescription(
            module: "RouteDocsTests",
            parent: .init(
                module: "Swift",
                parent: nil,
                name: "Dictionary",
                genericParameters: [
                    .init(module: "Swift", parent: nil, name: "String", genericParameters: []),
                    .init(
                        module: "Swift",
                        parent: .init(module: "Swift", parent: nil, name: "Dictionary", genericParameters: [
                            .init(module: "Swift", parent: nil, name: "String", genericParameters: []),
                            .init(module: "Swift", parent: nil, name: "Int", genericParameters: []),
                        ]),
                        name: "Index",
                        genericParameters: []
                    ),
                ]
            ),
            name: "SomeOtherNestedType",
            genericParameters: []
        )
        XCTAssertEqual(typeDesc1, expected1)
        XCTAssertEqual(typeDesc2, expected2)
    }
}
