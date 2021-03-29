import XCTest
@testable import RouteDocs

final class DocumentationDecoderTests: XCTestCase {
    struct Main: Decodable {
        struct Sub1: Decodable {
            private enum CodingKeys: String, CodingKey {
                case int, string
                case doubleArray = "doubles"
            }

            let int: Int
            let string: String
            let doubleArray: Array<Double>
        }

        struct Sub2: Decodable {
            let optional: Int?
            let doubleOptional: String??
            let intRange: ClosedRange<Int>
        }

        enum Sub3: Int, CaseIterable, Decodable, CustomDocumentable {
            case a = 0
            case b = 1

            static var documentationInstance: Sub3 { .a }
        }

        struct Sub4: Decodable {
            let int: Int
            let recursiveArray: Array<Sub4>
        }

        let bool: Bool
        let sub1: Sub1
        let sub2: Sub2
        let sub3: Sub3
        let optSub3: Sub3?
        let sub4: Sub4
        let date: Date
        let optionalUUID: UUID?
        let dateRange: Range<Date>
        let arbitraryDict: [String: Int]
    }

    func testDocObject() {
        XCTAssertFalse(DocumentationObject(Int.self).isOptional)
        XCTAssertTrue(DocumentationObject(Optional<Int>.self).isOptional)
    }

    func testSimpleStruct() throws {
        let doc = try Main.reflectedDocumentation(withCustomUserInfo: [:])
        let expectedDoc = DocumentationObject(Main.self, fields: [
            "bool": .init(Bool.self),
            "sub1": .init(Main.Sub1.self, fields: [
                "int": .init(Int.self),
                "string": .init(String.self),
                "doubles": .init(Array<Double>.self, fields: [
                    "{0...}": .init(Double.self),
                ]),
            ]),
            "sub2": .init(Main.Sub2.self, fields: [
                "optional": .init(Optional<Int>.self),
                "doubleOptional": .init(Optional<Optional<String>>.self),
                "intRange": .init(ClosedRange<Int>.self, fields: [
                    "0": .init(Int.self),
                    "1": .init(Int.self),
                ]),
            ]),
            "sub3": .init(casesOf: Main.Sub3.self),
            "optSub3": .init(Optional<Main.Sub3>.self, body: Main.Sub3.allCasesDocumentationBody),
            "sub4": .init(Main.Sub4.self, fields: [
                "int": .init(Int.self),
                "recursiveArray": .init(Array<Main.Sub4>.self, fields: [
                    "{0...}": .init(Main.Sub4.self, fields: [
                        "int": .init(Int.self),
                        "recursiveArray": .init(Array<Main.Sub4>.self, fields: [
                            "{0...}": .init(Main.Sub4.self, fields: [
                                "int": .init(Int.self),
                                "recursiveArray": .init(Array<Main.Sub4>.self, fields: [
                                    "{0...}": .init(Main.Sub4.self, fields: [
                                        "int": .init(Int.self),
                                        "recursiveArray": .init(Array<Main.Sub4>.self),
                                    ]),
                                ]),
                            ]),
                        ]),
                    ]),
                ]),
            ]),
            "date": .init(Date.self),
            "optionalUUID": .init(Optional<UUID>.self),
            "dateRange": .init(Range<Date>.self, fields: [
                "0": .init(Date.self),
                "1": .init(Date.self),
            ]),
            "arbitraryDict": .init(Dictionary<String, Int>.self, fields: [
                "{any}": .init(Int.self),
            ]),
        ])
        XCTAssertEqual(doc, expectedDoc)
    }

    func testPassingCustomUserInfo() throws {
        struct TestObject: Decodable {
            static var lastDecodedInstance: TestObject?

            let coderUserInfo: [CodingUserInfoKey: Any]

            init(from decoder: Decoder) throws {
                coderUserInfo = decoder.userInfo
                Self.lastDecodedInstance = self
            }
        }

        let intKey = CodingUserInfoKey(rawValue: "intKey")!
        let stringKey = CodingUserInfoKey(rawValue: "stringKey")!
        _ = try TestObject.reflectedDocumentation(withCustomUserInfo: [intKey: 42, stringKey: "ABC"])
        let obj = try XCTUnwrap(TestObject.lastDecodedInstance)
        XCTAssertEqual(obj.coderUserInfo[.isDocumentationDecoder] as? Bool, true)
        XCTAssertEqual(obj.coderUserInfo[intKey] as? Int, 42)
        XCTAssertEqual(obj.coderUserInfo[stringKey] as? String, "ABC")
    }
}
