public struct TypeDescription: Hashable, Sendable, Codable, CustomStringConvertible {
    private enum CodingKeys: String, CodingKey {
        case module, parent, name
        case genericParameters = "generic_parameters"
    }

    private enum _ParentStorage: Hashable, Sendable {
        case none
        indirect case some(TypeDescription)

        var value: TypeDescription? {
            switch self {
            case .none: return nil
            case .some(let desc): return desc
            }
        }
    }

    private let _parent: _ParentStorage

    public let module: String
    public var parent: TypeDescription? { _parent.value }
    public let name: String
    public let genericParameters: Array<TypeDescription>

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
        genericParameters: Array<TypeDescription>
    ) {
        self.module = module
        self._parent = parent.map(_ParentStorage.some) ?? .none
        self.name = name
        self.genericParameters = genericParameters
    }

    private init(decodedModule: String, container: KeyedDecodingContainer<CodingKeys>) throws {
        module = decodedModule
        _parent = try container.decodeIfPresent(TypeDescription.self, forKey: .parent).map(_ParentStorage.some) ?? .none
        name = try container.decode(String.self, forKey: .name)
        genericParameters = try container.decode(Array<TypeDescription>.self, forKey: .genericParameters)
    }

    private init(decodedType: TypeDescription, container: KeyedDecodingContainer<CodingKeys>) throws {
        module = decodedType.module
        _parent = decodedType._parent
        name = decodedType.name
        genericParameters = try container.decode(Array<TypeDescription>.self, forKey: .genericParameters)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let module: String
        do {
            module = try container.decode(String.self, forKey: .module)
        } catch DecodingError.keyNotFound(_, _) {
            let intermediateType =  try TypeParser.type(in: container.decode(String.self, forKey: .name))
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

    public func encode(to encoder: Encoder) throws {
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
        } else if options.contains(.withModule) { // parent has module already
            typeName.append(module)
        }
        typeName.append(name)
        typeName.append("<\(genericParameters.lazy.map { $0.typeName(with: options) }.joined(separator: ", "))>")
        return typeName
    }


    @available(*, deprecated, message: "Use typeName(with:)")
    public func typeName(includingModule: Bool = true) -> String {
        typeName(with: [includingModule ? .withModule : [], .withParents])
    }
}

extension TypeDescription {
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

fileprivate struct TypeParser<Text: StringProtocol> {
    private struct Context {
        let name: Text.SubSequence
        var generics = Array<TypeDescription>()

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
            case " ", "<": context.generics.append(parseSubtype())
            case ",", ">": break loop
            default: fatalError("Invalid type! Unexpected character: \(currentChar)")
            }
        }
        return context.typeDescription(in: module, parent: parent)
    }

    private mutating func parseModule() -> (String, isExtension: Bool) {
        if currentChar == "(" {
            let prefix = seek(to: ")").dropFirst() // Drop past the opening bracket
            seek(to: ":") // (...):MODULE.TYPENAME <- Move past the colon
            return (String(prefix.dropPrefix("extension in ") ?? prefix), true)
        } else {
            return (String(seek(to: ".")), false)
        }
    }

    private mutating func parseIdentifier() -> Text.SubSequence {
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
}

extension StringProtocol {
    fileprivate func dropPrefix(_ prefix: some StringProtocol) -> SubSequence? {
        guard starts(with: prefix) else { return nil }
        return dropFirst(prefix.count)
    }
}
