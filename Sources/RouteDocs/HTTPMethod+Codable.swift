import NIOHTTP1

extension HTTPMethod: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let method = HTTPMethod(rawValue: string) else {
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Could not create \(HTTPMethod.self) from \"\(string)\"")
        }
        self = method
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
