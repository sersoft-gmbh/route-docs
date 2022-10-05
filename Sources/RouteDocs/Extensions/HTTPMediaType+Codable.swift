import Vapor

extension HTTPMediaType: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, subtype, parameters
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(type: container.decode(String.self, forKey: .type),
                      subType: container.decode(String.self, forKey: .subtype),
                      parameters: container.decode([String: String].self, forKey: .parameters))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(subType, forKey: .subtype)
        try container.encode(parameters, forKey: .parameters)
    }
}
