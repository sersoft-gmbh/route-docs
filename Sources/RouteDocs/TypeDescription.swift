public struct TypeDescription: Sendable, Hashable, Codable, CustomStringConvertible {
    private enum CodingKeys: String, CodingKey {
        case module, parent, name
        case genericParameters = "generic_parameters"
    }

    private enum _ParentStorage: Sendable, Hashable {
        case none
        indirect case some(TypeDescription)

        var value: TypeDescription? {
            switch self {
            case .none: nil
            case .some(let desc): desc
            }
        }
    }

    public enum GenericParameter: Sendable, Hashable, Codable, CustomStringConvertible {
        private enum CodingKeys: String, CodingKey {
            enum IntegerLiteralKeys: String, CodingKey {
                case name, value
                case valueType = "value_type"
            }
            case type
            case integerLiteral = "integer_literal"
        }

        indirect case type(TypeDescription)
#if compiler(>=6.2)
        case integerLiteral(name: String?, value: Int, valueType: TypeDescription)
#endif

        public var description: String { typeName(with: [.withModule, .withParents]) }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            guard !container.allKeys.isEmpty else { // legacy
                self = .type(try TypeDescription(from: decoder))
                return
            }
            let hasType = container.allKeys.contains(.type)
            let hasIntegerLiteral = container.allKeys.contains(.integerLiteral)
            if hasType && hasIntegerLiteral {
                throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath,
                                                        debugDescription: "Cannot contain both 'type' and 'integerLiteral' keys"))
            }
            if hasType {
                self = try .type(container.decode(TypeDescription.self, forKey: .type))
            } else if hasIntegerLiteral {
                let subContainer = try container.nestedContainer(keyedBy: CodingKeys.IntegerLiteralKeys.self, forKey: .integerLiteral)
                self = try .integerLiteral(name: subContainer.decodeIfPresent(String.self, forKey: .name),
                                           value: subContainer.decode(Int.self, forKey: .value),
                                           valueType: subContainer.decode(TypeDescription.self, forKey: .valueType))
            } else {
                throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath,
                                                        debugDescription: "Requires either 'type' or 'integerLiteral' keys"))
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .type(let type):
                try container.encode(type, forKey: .type)
            case .integerLiteral(let name, let value, let valueType):
                var nestedContainer = container.nestedContainer(keyedBy: CodingKeys.IntegerLiteralKeys.self, forKey: .integerLiteral)
                try nestedContainer.encodeIfPresent(name, forKey: .name)
                try nestedContainer.encode(value, forKey: .value)
                try nestedContainer.encode(valueType, forKey: .valueType)
            }
        }

        func typeName(with options: NameOptions) -> String {
            switch self {
            case .type(let type): type.typeName(with: options)
            case .integerLiteral(_, let value, _): String(value)
            }
        }
    }

    private let _parent: _ParentStorage

    public let module: String
    public var parent: TypeDescription? { _parent.value }
    public let name: String
    public let genericParameters: Array<GenericParameter>

    public var parents: some Sequence<TypeDescription> {
        sequence(state: parent, next: { state in
            defer { state = state?.parent }
            return state
        })
    }

    @inlinable
    public var isGeneric: Bool { !genericParameters.isEmpty }

    @inlinable
    public var description: String { typeName(with: [.withModule, .withParents]) }

    // private but @testable
    init(
        module: String,
        parent: TypeDescription?,
        name: String,
        genericParameters: Array<GenericParameter>
    ) {
        assert(!module.isEmpty)
        self.module = module
        self._parent = parent.map(_ParentStorage.some) ?? .none
        self.name = name
        self.genericParameters = genericParameters
    }

    private init(decodedModule: String, container: KeyedDecodingContainer<CodingKeys>) throws {
        module = decodedModule
        _parent = try container.decodeIfPresent(TypeDescription.self, forKey: .parent).map(_ParentStorage.some) ?? .none
        name = try container.decode(String.self, forKey: .name)
        genericParameters = try container.decode(Array<GenericParameter>.self, forKey: .genericParameters)
    }

    private init(decodedType: TypeDescription, container: KeyedDecodingContainer<CodingKeys>) throws {
        module = decodedType.module
        _parent = decodedType._parent
        name = decodedType.name
        genericParameters = try container.decode(Array<GenericParameter>.self, forKey: .genericParameters)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let module: String
        do {
            module = try container.decode(String.self, forKey: .module)
        } catch DecodingError.keyNotFound(_, _) {
            let intermediateType = try TypeParser.type(in: container.decode(String.self, forKey: .name))
            try self.init(decodedType: intermediateType, container: container)
            return
        }
        try self.init(decodedModule: module, container: container)
    }

    public init<T>(_ type: T.Type) {
        self = TypeParser.type(in: String(reflecting: type))
    }

    public init(any type: Any.Type) {
        self = TypeParser.type(in: String(reflecting: type))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(module, forKey: .module)
        if case .some(let wrapped) = _parent {
            try container.encode(wrapped, forKey: .parent)
        }
        try container.encode(name, forKey: .name)
        try container.encode(genericParameters, forKey: .genericParameters)
    }

    public func typeName(with options: NameOptions = [.withModule, .withParents]) -> String {
        var typeName = String()
        if case .some(let parent) = _parent, options.contains(.withParents) {
            typeName.append(parent.typeName(with: options))
            typeName.append(".")
        } else if options.contains(.withModule) { // parent has module already
            typeName.append(module)
            typeName.append(".")
        }
        typeName.append(name)
        if !genericParameters.isEmpty {
            typeName.append("<\(genericParameters.lazy.map { $0.typeName(with: options) }.joined(separator: ", "))>")
        }
        return typeName
    }
}

extension TypeDescription {
    @frozen
    public struct NameOptions: OptionSet, Sendable {
        public typealias RawValue = UInt

        public let rawValue: RawValue

        public init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
    }
}

extension TypeDescription.NameOptions {
    public static let withModule = TypeDescription.NameOptions(rawValue: 1 << 0)
    public static let withParents = TypeDescription.NameOptions(rawValue: 1 << 1)
}

fileprivate struct TypeParser<Text: StringProtocol> where Text.SubSequence: RangeReplaceableCollection {
    fileprivate enum SpecialTypes<T: StringProtocol> {
        static var any: T { "Any" }
        static var void: T { "Void" }
        static var voidAsTuple: T { "()" }
    }

    private struct Context {
        let name: Text.SubSequence
        var generics = Array<TypeDescription.GenericParameter>()

        func typeDescription(in module: String, parent: TypeDescription?) -> TypeDescription {
            .init(module: module, parent: parent, name: String(name), genericParameters: generics)
        }
    }

    private let string: Text
    private var currentIndex: Text.Index

    private var currentChar: Text.Element {
        string[currentIndex]
    }

    private var remainder: Text.SubSequence {
        string[currentIndex...]
    }

    private init(string: Text) {
        self.string = string
        self.currentIndex = string.startIndex
    }

    static func type(in string: Text) -> TypeDescription {
        var parser = Self.init(string: string)
        return parser.parseType()
    }

    private mutating func parseType() -> TypeDescription {
        let (module, isExtension) = parseModule()
        if isExtension {
            let extendedType = parseSubtype()
            return .init(module: module,
                         parent: extendedType.parent,
                         name: extendedType.name,
                         genericParameters: extendedType.genericParameters)
        }

        var parent: TypeDescription?
        var context = Context(name: parseIdentifier())
    loop:
        while currentIndex < string.endIndex, case let char = currentChar {
            string.formIndex(after: &currentIndex)
            switch char {
            case ".":
                parent = context.typeDescription(in: module, parent: parent)
                context = .init(name: parseIdentifier())
            case " ", "<": context.generics.append(parseGenericParameter())
            case ",", ">": break loop
            default: fatalError("Invalid type! Unexpected character: \(currentChar)")
            }
        }
        return context.typeDescription(in: module, parent: parent)
    }

    private mutating func parseModule() -> (String, isExtension: Bool) {
        guard peekSpecialType() == nil else { return ("Swift", false) }
        if currentChar == "(" {
            let prefix = seek(to: ")").dropFirst() // Drop past the opening bracket
            seek(to: ":") // (...):MODULE.TYPENAME <- Move past the colon
            return (String(prefix.dropPrefix("extension in ") ?? prefix), true)
        }
        return (String(seek(to: ".")), false)
    }

    private mutating func parseIdentifier() -> Text.SubSequence {
        if let (index, specialType) = peekSpecialType() {
            currentIndex = index
            return specialType
        }
        if currentChar == "(" { // TODO: Where else can this occur?
            // (unknown context ...)
            seek(to: ".")
        }
        if let index = remainder.firstIndex(where: ".<,>".contains) {
            defer { currentIndex = index }
            return remainder[..<index]
        } else {
            defer { currentIndex = remainder.endIndex }
            return remainder
        }
    }

    private func peekSpecialType() -> (indexAfter: Text.Index, type: Text.SubSequence)? {
        let index = remainder.firstIndex(where: ",>".contains) ?? remainder.endIndex
        let identifier = remainder[..<index]
        switch identifier {
        case SpecialTypes.any, SpecialTypes.void: return (index, identifier)
        case SpecialTypes.voidAsTuple: return (index, SpecialTypes.void)
        default: return nil
        }
    }

#if compiler(>=6.2)
    private mutating func parseIntegerLiteralGenericParameter() -> Int? {
        let index = remainder.firstIndex(where: ",>".contains) ?? remainder.endIndex
        guard let value = Int(remainder[..<index]) else { return nil }
        currentIndex = remainder.index(after: index)
        return value
    }
#endif

    @discardableResult
    private mutating func seek(to char: Text.Element) -> Text.SubSequence {
        guard let index = remainder.firstIndex(of: char)
        else { fatalError("Invalid type! Missing '\(char)' in '\(remainder)'") }
        defer { currentIndex = remainder.index(after: index) }
        return remainder[..<index]
    }

    private mutating func parseSubtype() -> TypeDescription {
        var subParser = TypeParser<Text.SubSequence>(string: remainder)
        defer { currentIndex = subParser.currentIndex }
        return subParser.parseType()
    }

    private mutating func parseGenericParameter() -> TypeDescription.GenericParameter {
        var subParser = TypeParser<Text.SubSequence>(string: remainder)
        defer { currentIndex = subParser.currentIndex }
#if compiler(>=6.2)
        if let value = subParser.parseIntegerLiteralGenericParameter() {
            return .integerLiteral(name: nil, value: value, valueType: TypeDescription(Int.self))
        }
#endif
        return .type(subParser.parseType())
    }
}

extension StringProtocol {
    fileprivate func dropPrefix(_ prefix: some StringProtocol) -> SubSequence? {
        guard starts(with: prefix) else { return nil }
        return dropFirst(prefix.count)
    }
}
