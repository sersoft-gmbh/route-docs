import Foundation
import Testing
@testable import RouteDocs

#if compiler(>=6.2)
fileprivate let integerLiteralGenericParametersAvailable = true
#else
fileprivate let integerLiteralGenericParametersAvailable = false
#endif

extension Dictionary {
    enum SomeNestedType {}
    fileprivate enum SomeOtherNestedType {}
}

fileprivate extension TypeDescription {
    init(
        module: String,
        parent: TypeDescription?,
        name: String,
        genericParameters: some Sequence<TypeDescription>
    ) {
        self.init(module: module, parent: parent, name: name, genericParameters: genericParameters.map { .type($0) })
    }
}

@Suite
struct TypeDescriptionTests {
    private var uuidModule: String {
#if canImport(FoundationEssentials)
        "FoundationEssentials"
#else
        "Foundation"
#endif
    }

    @Test
    func variousTypes() {
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
        #expect(typeDesc1 == expected1)
        #expect(typeDesc2 == expected2)
    }

    @Test
    func specialTypes() {
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
        #expect(anyTypeDesc == anyExpected)
        #expect(voidTypeDesc == voidExpected)
        #expect(deeperAnyTypeDesc == deeperAnyExpected)
        #expect(deeperVoidTypeDesc == deeperVoidExpected)
    }

    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    func bigIntegerTypes() {
        let int128Desc = TypeDescription(Int128.self)
        let int128Expected = TypeDescription(module: "Swift", parent: nil, name: "Int128", genericParameters: [])
        let uint128Desc = TypeDescription(UInt128.self)
        let uint128Expected = TypeDescription(module: "Swift", parent: nil, name: "UInt128", genericParameters: [])

        #expect(int128Desc == int128Expected)
        #expect(uint128Desc == uint128Expected)
    }

    @Test(.enabled(if: integerLiteralGenericParametersAvailable))
    @available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
    func integerLiteralGenericTypes() {
#if compiler(>=6.2)
        let inlineArray = TypeDescription(InlineArray<5, String>.self)
        let expectedInlineArray = TypeDescription(module: "Swift", parent: nil, name: "InlineArray", genericParameters: [
            .integerLiteral(name: nil, value: 5, valueType: .init(module: "Swift", parent: nil, name: "Int", genericParameters: [])),
            .type(.init(module: "Swift", parent: nil, name: "String", genericParameters: [])),
        ])
        #expect(inlineArray == expectedInlineArray)
#endif
    }
}
