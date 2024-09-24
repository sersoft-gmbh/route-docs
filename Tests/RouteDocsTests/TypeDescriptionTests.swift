import Foundation
import XCTest
@testable import RouteDocs

extension Dictionary {
    enum SomeNestedType {}
    fileprivate enum SomeOtherNestedType {}
}

final class TypeDescriptionTests: XCTestCase {
    private var uuidModule: String {
#if canImport(FoundationEssentials)
        return "FoundationEssentials"
#else
        return "Foundation"
#endif
    }

    func testVariousTypes() {
        let typeDesc1 = TypeDescription(Dictionary<String, Dictionary<String, Int>.SomeNestedType>.Index.self)
        let typeDesc2 = TypeDescription(Dictionary<UUID, Dictionary<String, Int>.Index>.SomeOtherNestedType.self)
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
                    .init(module: uuidModule, parent: nil, name: "UUID", genericParameters: []),
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

    func testSpecialTypes() {
        let anyTypeDesc = TypeDescription(Any.self)
        let anyExpected = TypeDescription(module: "Swift", parent: nil, name: "Any", genericParameters: [])
        let voidTypeDesc = TypeDescription(Void.self)
        let voidExpected = TypeDescription(module: "Swift", parent: nil, name: "Void", genericParameters: [])
        let deeperAnyTypeDesc = TypeDescription(Dictionary<String, Array<Any>>.self)
        let deeperAnyExpected = TypeDescription(module: "Swift", parent: nil, name: "Dictionary", genericParameters: [
            .init(module: "Swift", parent: nil, name: "String", genericParameters: []),
            .init(module: "Swift", parent: nil, name: "Array", genericParameters: [anyExpected]),
        ])
        let deeperVoidTypeDesc = TypeDescription(Dictionary<UUID, Array<Void>>.self)
        let deeperVoidExpected = TypeDescription(module: "Swift", parent: nil, name: "Dictionary", genericParameters: [
            .init(module: uuidModule, parent: nil, name: "UUID", genericParameters: []),
            .init(module: "Swift", parent: nil, name: "Array", genericParameters: [voidExpected]),
        ])
        XCTAssertEqual(anyTypeDesc, anyExpected)
        XCTAssertEqual(voidTypeDesc, voidExpected)
        XCTAssertEqual(deeperAnyTypeDesc, deeperAnyExpected)
        XCTAssertEqual(deeperVoidTypeDesc, deeperVoidExpected)
    }
}
