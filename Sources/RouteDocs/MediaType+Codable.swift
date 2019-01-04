import Vapor

extension CaseInsensitiveString: Codable {
    public init(from decoder: Decoder) throws {
        try self.init(decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

extension MediaType: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, subtype, parameters
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(type: container.decode(String.self, forKey: .type),
                      subType: container.decode(String.self, forKey: .subtype),
                      parameters: container.decode([CaseInsensitiveString: String].self, forKey: .parameters))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(subType, forKey: .subtype)
        try container.encode(parameters, forKey: .parameters)
    }
}
