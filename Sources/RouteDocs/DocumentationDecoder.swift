import NIOConcurrencyHelpers
import Vapor

extension CodingUserInfoKey {
    public static let isDocumentationDecoder = CodingUserInfoKey(rawValue: "IsDocumentationDecoder")!
}

public struct DocumentationObject: Hashable, CustomStringConvertible {
    public enum Body: Hashable {
        public struct EnumCase: Hashable {
            public let name: String?
            public let value: String

            public init(name: String? = nil, value: String) {
                self.name = name
                self.value = value
            }

            public init<R: RawRepresentable>(value: R) {
                let rawValueDesc = String(describing: value.rawValue)
                let valueDesc = String(describing: value)
                self.init(name: rawValueDesc == valueDesc ? nil : valueDesc, value: rawValueDesc)
            }
        }

        case none
        case fields([String: DocumentationObject])
        case cases([EnumCase])

        public var isEmpty: Bool {
            switch self {
            case .none: return true
            case .fields(let fields): return fields.isEmpty
            case .cases(let cases): return cases.isEmpty
            }
        }

        fileprivate var fields: [String: DocumentationObject]? {
            get {
                switch self {
                case .none: return [:]
                case .fields(let fields): return fields
                case .cases(_): return nil
                }
            }
            set {
                guard let new = newValue else { return }
                if case .cases(_) = self { return }
                self = new.isEmpty ? .none : .fields(new)
            }
        }
    }

    public let type: Any.Type
    public fileprivate(set) var body: Body

    public var isOptional: Bool { type is AnyOptionalType.Type }

    public var description: String { description(indentedBy: 0) }

    fileprivate init(any type: Any.Type, body: Body) {
        self.type = type
        self.body = body
    }

    public init<T>(_ type: T.Type, body: Body = .none) {
        self.init(any: type, body: body)
    }

    @inlinable
    public init<T>(_ type: T.Type, fields: [String: DocumentationObject]) {
        self.init(type, body: .fields(fields))
    }

    @inlinable
    public init<T>(casesOf type: T.Type) where T: CaseIterable, T: RawRepresentable {
        self.init(type, body: type.allCasesDocumentationBody)
    }

    private func description(indentedBy indentionLevel: Int, indentionIncrement: Int = 3) -> String {
        guard !body.isEmpty else { return "\(type)" }
        let fieldIndention = String(repeating: " ", count: indentionLevel + indentionIncrement)
        let bodyDesc: String
        switch body {
        case .none: return "\(type)"
        case .fields(let fields):
            bodyDesc = fields.sorted { $0.key < $1.key }.map {
                "\(fieldIndention)\($0.key): \($0.value.description(indentedBy: indentionLevel + indentionIncrement, indentionIncrement: indentionIncrement))"
            }.joined(separator: "\n")
        case .cases(let cases):
            bodyDesc = cases.sorted { $0.value < $1.value }.map {
                "\(fieldIndention)- \($0.name.map { "\($0): " } ?? "")\($0.value)"
            }.joined(separator: "\n")
        }
        return """
        \(type) {
        \(bodyDesc)
        \(String(repeating: " ", count: indentionLevel))}
        """
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(type))
        hasher.combine(body)
    }

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.type == rhs.type && lhs.body == rhs.body
    }
}

public protocol CustomDocumentationNamed {
    static var documentationName: String { get }
}

public protocol AnyCustomDocumentable {
    static var documentationBody: DocumentationObject.Body { get }
    static var anyDocumentationInstance: Any { get }
}

public protocol CustomDocumentable: AnyCustomDocumentable {
    static var documentationInstance: Self { get }
}

extension CustomDocumentable {
    @inlinable
    public static var anyDocumentationInstance: Any { documentationInstance }
}

extension AnyCustomDocumentable {
    static func object(with type: Any.Type) -> DocumentationObject { .init(any: type, body: documentationBody) }
}

extension Optional: AnyCustomDocumentable, CustomDocumentable where Wrapped: CustomDocumentable {
    public static var documentationBody: DocumentationObject.Body { Wrapped.documentationBody }
    public static var documentationInstance: Self { .some(Wrapped.documentationInstance) }
}

extension Decodable {
    static func reflectedDocumentation(withCustomUserInfo customUserInfo: [CodingUserInfoKey: Any]) throws -> DocumentationObject {
        let decoder = DocumentationDecoder(type: self, customUserInfo: customUserInfo)
        _ = try self.init(from: decoder)
        return decoder.storage.decodedObject
    }
}

fileprivate struct DocumentationDecoder: Decoder {
    let storage: Storage
    let codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]

    private init(storage: Storage, codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any]) {
        self.storage = storage
        self.codingPath = codingPath
        self.userInfo = userInfo
    }

    init<T>(type: T.Type, customUserInfo: [CodingUserInfoKey: Any]) {
        var userInfo = customUserInfo
        userInfo[.isDocumentationDecoder] = true
        self.init(storage: .init(type: type), codingPath: [], userInfo: userInfo)
    }

    func push<C: CodingKey>(key: C) -> DocumentationDecoder {
        .init(storage: storage, codingPath: codingPath + CollectionOfOne<CodingKey>(key), userInfo: userInfo)
    }

    func popKey() -> DocumentationDecoder {
        .init(storage: storage, codingPath: codingPath.dropLast(), userInfo: userInfo)
    }

    func hasPotentialCycle() -> Bool { storage.hasPotentialCycle(at: codingPath) }

    func withCurrentCodingPath<T>(do work: (inout DocumentationObject) throws -> T) throws -> T {
        try storage.withCodingPath(codingPath, do: work)
    }

    func setType<C: CodingKey>(_ type: Any.Type, for key: C) throws {
        try storage.setType(type, for: key, at: codingPath)
    }

    func finalizeObject<T: Decodable, C: CodingKey>(ofType type: Any.Type, for key: C) throws -> T {
        func cache(_ object: T) throws {
            try Cache.cache(entry: .init(object: object,
                                         documentation: storage.withCodingPath(codingPath + CollectionOfOne<CodingKey>(key),
                                                                               do: { $0 })))
        }
        if let cachedElement = Cache.cachedValue(for: type) {
            try storage.setObject(cachedElement.documentation, for: key, at: codingPath)
            return cachedElement.object as! T
        }
        if let customDocumentable = T.self as? AnyCustomDocumentable.Type {
            try storage.setObject(customDocumentable.object(with: type), for: key, at: codingPath)
            let result = customDocumentable.anyDocumentationInstance as! T
            try cache(result)
            return result
        }
        try setType(type, for: key)
        let result = try T(from: push(key: key))
        try cache(result)
        return result
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        SingleValueContainer(decoder: self)
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        KeyedDecodingContainer(KeyedContainer(decoder: self))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        UnkeyedContainer(decoder: self)
    }
}

extension DocumentationDecoder {
    fileprivate final class Storage {
        private struct KeyTypeCombination: Hashable {
            let key: String
            let type: Any.Type

            func hash(into hasher: inout Hasher) {
                hasher.combine(key)
                hasher.combine(ObjectIdentifier(type))
            }

            static func ==(lhs: KeyTypeCombination, rhs: KeyTypeCombination) -> Bool {
                lhs.key == rhs.key && lhs.type == rhs.type
            }
        }

        private(set) var decodedObject: DocumentationObject

        private var keyTypeCounts = Dictionary<KeyTypeCombination, Int>()

        init<T>(type: T.Type) {
            decodedObject = .init(any: type, body: .none)
        }

        func withCodingPath<C, T>(_ path: C, do work: (inout DocumentationObject) throws -> T) throws -> T
        where C: Collection, C.Element == CodingKey
        {
            func withPath<P>(remainingPath: P, of object: inout DocumentationObject, do work: (inout DocumentationObject) throws -> T) throws -> T
            where P: Collection, P.Element == C.Element
            {
                guard !remainingPath.isEmpty else { return try work(&object) }
                let nextKey = remainingPath[remainingPath.startIndex]
                guard var nextObject = object.body.fields?[nextKey.stringValue] else {
                    throw DecodingError.keyNotFound(nextKey, .init(codingPath: path.dropLast(remainingPath.count),
                                                                   debugDescription: "No documentation field was decoded (yet) at the given path!"))
                }
                defer { object.body.fields?[nextKey.stringValue] = nextObject }
                return try withPath(remainingPath: remainingPath.dropFirst(), of: &nextObject, do: work)
            }
            return try withPath(remainingPath: path, of: &decodedObject, do: work)
        }

        func setObject<C, P>(_ object: @autoclosure() -> DocumentationObject, for key: C, at codingPath: P) throws
        where C: CodingKey, P: Collection, P.Element == CodingKey
        {
            try withCodingPath(codingPath, do: { $0.body.fields?[key.stringValue] = object() })
        }

        func setType<C, P>(_ type: Any.Type, for key: C, at codingPath: P) throws
        where C: CodingKey, P: Collection, P.Element == CodingKey
        {
            try setObject(.init(any: type, body: .none), for: key, at: codingPath)
            keyTypeCounts[KeyTypeCombination(key: key.stringValue, type: type), default: 0] += 1
        }

        func hasPotentialCycle<P>(at codingPath: P) -> Bool
        where P: BidirectionalCollection, P.Element == CodingKey
        {
            guard let last = codingPath.last,
                  let existingEntry = try? withCodingPath(codingPath, do: { $0 })
            else { return false }
            return keyTypeCounts[.init(key: last.stringValue, type: existingEntry.type), default: 0] > 3
        }
    }

    fileprivate enum Cache {
        struct Entry {
            let object: Decodable
            let documentation: DocumentationObject
        }

        private static let lock = Lock()
        private static var cache: [ObjectIdentifier: Entry] = [:]

        static func cachedValue(for type: Any.Type) -> Entry? {
            lock.withLock { cache[ObjectIdentifier(type)] }
        }

        static func cache(entry: Entry) {
            lock.withLock { cache[ObjectIdentifier(type(of: entry.object))] = entry }
        }
    }

    fileprivate final class TypeBuilder {
        private var isOptional = false

        func makeOptional() {
            isOptional = true
        }

        func finalizeType<T>(with _: T.Type) -> Any.Type {
            defer { isOptional = false }
            return isOptional ? Optional<T>.self : T.self
        }
    }

    fileprivate struct SingleValueContainer: SingleValueDecodingContainer {
        let decoder: DocumentationDecoder

        var codingPath: [CodingKey] { decoder.codingPath }

        func decodeNil() -> Bool { false }
        func decode(_ type: Bool.Type) throws -> Bool { .init() }
        func decode(_ type: String.Type) throws -> String { .init() }
        func decode(_ type: Double.Type) throws -> Double { .init() }
        func decode(_ type: Float.Type) throws -> Float { .init() }
        func decode(_ type: Int.Type) throws -> Int { .init() }
        func decode(_ type: Int8.Type) throws -> Int8 { .init() }
        func decode(_ type: Int16.Type) throws -> Int16 { .init() }
        func decode(_ type: Int32.Type) throws -> Int32 { .init() }
        func decode(_ type: Int64.Type) throws -> Int64 { .init() }
        func decode(_ type: UInt.Type) throws -> UInt { .init() }
        func decode(_ type: UInt8.Type) throws -> UInt8 { .init() }
        func decode(_ type: UInt16.Type) throws -> UInt16 { .init() }
        func decode(_ type: UInt32.Type) throws -> UInt32 { .init() }
        func decode(_ type: UInt64.Type) throws -> UInt64 { .init() }
        func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
            try type.init(from: decoder)
        }
    }

    fileprivate struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let decoder: DocumentationDecoder

        private let builder = TypeBuilder()

        var codingPath: [CodingKey] { decoder.codingPath }

        var allKeys: [Key] {
            guard !decoder.hasPotentialCycle() else { return [] }
            return Key(stringValue: "{any}").map { [$0] } ?? []
        }

        private func finalize<T>(with type: T.Type, for key: Key) throws {
            try decoder.setType(builder.finalizeType(with: type), for: key)
        }

        func contains(_ key: Key) -> Bool { !decoder.hasPotentialCycle() }

        func decodeNil(forKey key: Key) throws -> Bool {
            guard !decoder.hasPotentialCycle() else { return true }
            builder.makeOptional()
            return false
        }

        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
            try finalize(with: type, for: key)
            return .init()
        }

        func decode(_ type: String.Type, forKey key: Key) throws -> String {
            try finalize(with: type, for: key)
            return .init()
        }

        func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
            try finalize(with: type, for: key)
            return .init()
        }

        func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
            try finalize(with: type, for: key)
            return .init()
        }

        func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
            try finalize(with: type, for: key)
            return .init()
        }

        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
            try finalize(with: type, for: key)
            return .init()
        }

        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
            try finalize(with: type, for: key)
            return .init()
        }

        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
            try finalize(with: type, for: key)
            return .init()
        }

        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
            try finalize(with: type, for: key)
            return .init()
        }

        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
            try finalize(with: type, for: key)
            return .init()
        }

        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
            try finalize(with: type, for: key)
            return .init()
        }

        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
            try finalize(with: type, for: key)
            return .init()
        }

        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
            try finalize(with: type, for: key)
            return .init()
        }

        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
            try finalize(with: type, for: key)
            return .init()
        }

        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
            try decoder.finalizeObject(ofType: builder.finalizeType(with: type), for: key)
        }

        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            KeyedDecodingContainer(KeyedContainer<NestedKey>(decoder: decoder.push(key: key)))
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            UnkeyedContainer(decoder: decoder.push(key: key))
        }

        func superDecoder() throws -> Decoder { decoder }
        func superDecoder(forKey key: Key) throws -> Decoder { decoder.push(key: key) }
    }

    fileprivate struct UnkeyedContainer: UnkeyedDecodingContainer {
        private struct IndexKey: CodingKey {
            let index: Int

            var intValue: Int? { index }
            var stringValue: String { String(index) }

            init(index: Int) {
                self.index = index
            }

            init?(stringValue: String) {
                guard let idx = Int(stringValue) else { return nil }
                self.init(index: idx)
            }

            init?(intValue: Int) {
                self.init(index: intValue)
            }
        }
//        private struct OpenEndedListKey: CodingKey {
//            var intValue: Int? { nil }
//            var stringValue: String { "{0...}" }
//
//            init?(intValue: Int) { nil }
//            init?(stringValue: String) { nil }
//            init() {}
//        }

        let decoder: DocumentationDecoder

        private let builder = TypeBuilder()

        var codingPath: [CodingKey] { decoder.codingPath }

        var count: Int? { nil }
        var isAtEnd: Bool { currentIndex >= 10 || decoder.hasPotentialCycle() }

        private(set) var currentIndex = 0

        private mutating func finalize<T>(with type: T.Type, for key: IndexKey) throws {
            try decoder.setType(builder.finalizeType(with: type), for: key)
        }

        private mutating func finalize<T>(with type: T.Type) throws {
            try finalize(with: type, for: IndexKey(index: currentIndex))
            currentIndex += 1
            try compressTypeFieldsIfNeeded()
        }

        private func compressTypeFieldsIfNeeded() throws {
            guard isAtEnd else { return }
            try decoder.withCurrentCodingPath {
                guard let unique = $0.body.fields.map({ Set($0.values) }), unique.count == 1 else { return }
                $0.body = .fields(["{0...}": unique[unique.startIndex]])
            }
        }

        mutating func decodeNil() throws -> Bool {
            builder.makeOptional()
            return false
        }

        mutating func decode(_ type: Bool.Type) throws -> Bool {
            try finalize(with: type)
            return .init()
        }

        mutating func decode(_ type: String.Type) throws -> String {
            try finalize(with: type)
            return .init()
        }

        mutating func decode(_ type: Double.Type) throws -> Double {
            try finalize(with: type)
            return .init()
        }

        mutating func decode(_ type: Float.Type) throws -> Float {
            try finalize(with: type)
            return .init()
        }

        mutating func decode(_ type: Int.Type) throws -> Int {
            try finalize(with: type)
            return .init()
        }

        mutating func decode(_ type: Int8.Type) throws -> Int8 {
            try finalize(with: type)
            return .init()
        }

        mutating func decode(_ type: Int16.Type) throws -> Int16 {
            try finalize(with: type)
            return .init()
        }

        mutating func decode(_ type: Int32.Type) throws -> Int32 {
            try finalize(with: type)
            return .init()
        }

        mutating func decode(_ type: Int64.Type) throws -> Int64 {
            try finalize(with: type)
            return .init()
        }

        mutating func decode(_ type: UInt.Type) throws -> UInt {
            try finalize(with: type)
            return .init()
        }

        mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
            try finalize(with: type)
            return .init()
        }

        mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
            try finalize(with: type)
            return .init()
        }

        mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
            try finalize(with: type)
            return .init()
        }

        mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
            try finalize(with: type)
            return .init()
        }

        mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            let key = IndexKey(index: currentIndex)
            let result: T = try decoder.finalizeObject(ofType: builder.finalizeType(with: type), for: key)
            currentIndex += 1
            try compressTypeFieldsIfNeeded()
            return result
        }

        mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            defer { currentIndex += 1 }
            return KeyedDecodingContainer(KeyedContainer(decoder: decoder.push(key: IndexKey(index: currentIndex))))
        }

        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            defer { currentIndex += 1 }
            return UnkeyedContainer(decoder: decoder.push(key: IndexKey(index: currentIndex)))
        }

        mutating func superDecoder() throws -> Decoder { decoder }
    }
}
