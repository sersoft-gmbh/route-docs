import Leaf

public struct HashedTag: LeafTag {
    public init() {}

    public func render(_ ctx: LeafContext) throws -> LeafData {
        try ctx.requireParameterCount(1)
        if ctx.body?.isEmpty != true { // A bug in leaf currently gives all tags an empty body.
            try ctx.requireNoBody()
        }
        guard let string = ctx.parameters[0].string else {
            return ctx.parameters[0]
        }
        return .string(string)
    }
}
