import Foundation
import Testing
@testable import RouteDocs

@Suite
struct DocumentationDecoderTests {
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
        let arbitraryDict: Dictionary<String, Int>
    }

    @Test
    func docObject() {
        #expect(!DocumentationObject(Int.self).isOptional)
        #expect(DocumentationObject(Optional<Int>.self).isOptional)
    }

    @Test
    func simpleStruct() throws {
        let doc = try Main.reflectedDocumentation(withCustomUserInfo: .init())
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
        #expect(doc == expectedDoc)
    }

    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    struct BigTypes: Decodable {
        struct RawInt128: RawRepresentable, Decodable {
            typealias RawValue = Int128

            let rawValue: RawValue
        }

        struct RawUInt128: RawRepresentable, Decodable {
            typealias RawValue = UInt128

            let rawValue: UInt128
        }

        let int128: Int128
        let uint128: UInt128

        let rawInt128: RawInt128
        let rawUInt128: RawUInt128

        let int128Array: Array<Int128>
        let uint128Array: Array<UInt128>
    }

    @Test
    @available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
    func bigObjects() throws {
        let doc = try BigTypes.reflectedDocumentation(withCustomUserInfo: .init())
        let expectedDoc = DocumentationObject(BigTypes.self, fields: [
            "int128": .init(Int128.self),
            "uint128": .init(UInt128.self),
            "rawInt128": .init(BigTypes.RawInt128.self),
            "rawUInt128": .init(BigTypes.RawUInt128.self),
            "int128Array": .init(Array<Int128>.self, fields: [
                "{0...}": .init(Int128.self),
            ]),
            "uint128Array": .init(Array<UInt128>.self, fields: [
                "{0...}": .init(UInt128.self),
            ]),
        ])
        #expect(doc == expectedDoc)
    }

    @Test
    func passingCustomUserInfo() throws {
        struct TestObject: Decodable {
#if compiler(>=6.2)
            @safe
            static nonisolated(unsafe) var lastDecodedInstance: TestObject?
#else
            static nonisolated(unsafe) var lastDecodedInstance: TestObject?
#endif

            let coderUserInfo: Dictionary<CodingUserInfoKey, Any>

            init(from decoder: any Decoder) throws {
                coderUserInfo = decoder.userInfo
                Self.lastDecodedInstance = self
            }
        }

        let intKey = CodingUserInfoKey(rawValue: "intKey")!
        let stringKey = CodingUserInfoKey(rawValue: "stringKey")!
        _ = try TestObject.reflectedDocumentation(withCustomUserInfo: [intKey: 42, stringKey: "ABC"])
        let obj = try #require(TestObject.lastDecodedInstance)
        #expect(obj.coderUserInfo[.isDocumentationDecoder] as? Bool == true)
        #expect(obj.coderUserInfo[intKey] as? Int == 42)
        #expect(obj.coderUserInfo[stringKey] as? String == "ABC")
    }
}
