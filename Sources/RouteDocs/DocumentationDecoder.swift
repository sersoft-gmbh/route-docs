import NIOConcurrencyHelpers
//import Echo

extension CodingUserInfoKey {
    public static let isDocumentationDecoder = CodingUserInfoKey(rawValue: "IsDocumentationDecoder")!
}

public struct DocumentationObject: Hashable, CustomStringConvertible {
    public let type: Any.Type
    public fileprivate(set) var fields: [String: DocumentationObject]

    public var isOptional: Bool { type is _OptionalType.Type }

    public var description: String { description(indentedBy: 0) }

    public init<T>(_ type: T.Type, fields: [String: DocumentationObject] = [:]) {
        self.type = type
        self.fields = fields
    }

    fileprivate init(any type: Any.Type, fields: [String: DocumentationObject] = [:]) {
        self.type = type
        self.fields = fields
    }

    private func description(indentedBy indentionLevel: Int, indentionIncrement: Int = 3) -> String {
        guard !fields.isEmpty else { return "\(type)" }
        let typeIndention = String(repeating: " ", count: indentionLevel)
        let fieldIndention = String(repeating: " ", count: indentionLevel + indentionIncrement)
        let fieldsDesc = fields.sorted { $0.key < $1.key }.map {
            "\(fieldIndention)\($0.key): \($0.value.description(indentedBy: indentionLevel + indentionIncrement, indentionIncrement: indentionIncrement))"
        }.joined(separator: "\n")
        return """
        \(type) {
        \(fieldsDesc)
        \(typeIndention)}
        """
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(type))
        hasher.combine(fields)
    }

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.type == rhs.type && lhs.fields == rhs.fields
    }
}

public protocol AnyCustomDocumentable {
    static var documentationFields: [String: DocumentationObject] { get }
    static var anyDocumentationInstance: Any { get }
}

public protocol CustomDocumentable: AnyCustomDocumentable {
    static var documentationInstance: Self { get }
}

extension CustomDocumentable {
    @inlinable
    public static var anyDocumentationInstance: Any { documentationInstance }
}

fileprivate extension AnyCustomDocumentable {
    static func object(with type: Any.Type) -> DocumentationObject { .init(any: type, fields: documentationFields) }
}

extension Decodable {
    static func reflectedDocumentation() throws -> DocumentationObject {
        let decoder = DocumentationDecoder(type: self)
        _ = try self.init(from: decoder)
        return decoder.storage.decodedObject
    }
}

fileprivate protocol _OptionalType {}
extension Optional: _OptionalType {}

fileprivate struct DocumentationDecoder: Decoder {

    let storage: Storage

    let codingPath: [CodingKey]

    var userInfo: [CodingUserInfoKey: Any] { [.isDocumentationDecoder: true] }

    init(storage: Storage, codingPath: [CodingKey]) {
        self.storage = storage
        self.codingPath = codingPath
    }

    init<T>(type: T.Type) { self.init(storage: .init(type: type), codingPath: []) }

    func push<C: CodingKey>(key: C) -> DocumentationDecoder {
        .init(storage: storage, codingPath: codingPath + CollectionOfOne<CodingKey>(key))
    }

    func withCurrentCodingPath<T>(do work: (inout DocumentationObject) throws -> T) throws -> T {
        try storage.withCodingPath(codingPath, do: work)
    }

    func setType<C>(_ type: Any.Type, for key: C) throws
        where C: CodingKey
    {
        try storage.setType(type, for: key, at: codingPath)
    }

    func finalizeObject<T, C>(ofType type: Any.Type, for key: C) throws -> T
        where T: Decodable, C: CodingKey
    {
        func cache(_ object: T) throws {
            try Cache.cache(entry: .init(object: object,
                                         documentation: storage.withCodingPath(codingPath + CollectionOfOne<CodingKey>(key),
                                                                               do: { $0 })))
        }
        if let cachedElement = Cache.cachedValue(for: type) {
            try storage.setObject(cachedElement.documentation, for: key, at: codingPath)
            return cachedElement.object as! T
        }
        if let customDocumentable = type as? AnyCustomDocumentable.Type {
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
        private(set) var decodedObject: DocumentationObject

        init<T>(type: T.Type) {
            decodedObject = .init(type)
        }

        func withCodingPath<C, T>(_ path: C, do work: (inout DocumentationObject) throws -> T) throws -> T
            where C: Collection, C.Element == CodingKey
        {
            func withPath<P>(remainingPath: P, of object: inout DocumentationObject, do work: (inout DocumentationObject) throws -> T) throws -> T
                where P: Collection, P.Element == C.Element
            {
                guard !remainingPath.isEmpty else { return try work(&object) }
                let nextKey = remainingPath[remainingPath.startIndex]
                guard var nextObject = object.fields[nextKey.stringValue] else {
                    throw DecodingError.keyNotFound(nextKey, .init(codingPath: path.dropLast(remainingPath.count),
                                                                   debugDescription: "No documentation field was decoded (yet) at the given path!"))
                }
                defer { object.fields[nextKey.stringValue] = nextObject }
                return try withPath(remainingPath: remainingPath.dropFirst(), of: &nextObject, do: work)
            }
            return try withPath(remainingPath: path, of: &decodedObject, do: work)
        }

        func setType<C, P>(_ type: Any.Type, for key: C, at codingPath: P) throws
            where C: CodingKey, P: Collection, P.Element == CodingKey
        {
            try setObject(.init(any: type), for: key, at: codingPath)
        }

        func setObject<C, P>(_ object: @autoclosure() -> DocumentationObject, for key: C, at codingPath: P) throws
            where C: CodingKey, P: Collection, P.Element == CodingKey
        {
            try withCodingPath(codingPath, do: { $0.fields[key.stringValue] = object() })
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

        func finalizeType<T>(with type: T.Type) -> Any.Type {
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
        func decode<T>(_ type: T.Type) throws -> T where T : Decodable { try type.init(from: decoder) }
    }

    struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let decoder: DocumentationDecoder

        private let builder = TypeBuilder()

        var codingPath: [CodingKey] { decoder.codingPath }

        var allKeys: [Key] {
//            let x = reflect(Key.self)
//            switch x.kind {
//            case .enum:
//                let meta = x as! EnumMetadata
//
//            }
//            print(Key.self)
            return []
        }

        private func finalize<T>(with type: T.Type, for key: Key) throws {
            try decoder.setType(builder.finalizeType(with: type), for: key)
        }

        func contains(_ key: Key) -> Bool { true }

        func decodeNil(forKey key: Key) throws -> Bool {
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

    struct UnkeyedContainer: UnkeyedDecodingContainer {
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

        let decoder: DocumentationDecoder

        private let builder = TypeBuilder()

        var codingPath: [CodingKey] { decoder.codingPath }

        var count: Int? { nil }
        var isAtEnd: Bool { currentIndex >= 10 }

        private(set) var currentIndex: Int = 0

        private mutating func finalize<T>(with type: T.Type, for key: IndexKey) throws {
            try decoder.setType(builder.finalizeType(with: type), for: IndexKey(index: currentIndex))
        }

        private mutating func finalize<T>(with type: T.Type) throws {
            try finalize(with: type, for: IndexKey(index: currentIndex))
            currentIndex += 1
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
