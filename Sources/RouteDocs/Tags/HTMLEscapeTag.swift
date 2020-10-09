import Leaf

public struct EscapeTag: LeafTag {
    public init() {}
    
    public func render(_ ctx: LeafContext) throws -> LeafData {
        try ctx.requireParameterCount(1)
        if ctx.body?.isEmpty != true { // A bug in leaf currently gives all tags an empty body.
            try ctx.requireNoBody()
        }
        guard let string = ctx.parameters[0].string else {
            return ctx.parameters[0]
        }
        return .string(string.htmlEscaped())
    }
}

// This is copied (and slightly adjusted) from Leaf 3. Leaf 4 does not escape text anymore.
extension String {
    /// Lookup table mapping the characters that need escaping to their escaped representation.
    private static let htmlEscapeMap: [UInt8: String] = [
        UInt8(ascii: "&"): "&amp;",
        UInt8(ascii: "\""): "&quot;",
        UInt8(ascii: "'"): "&#39;",
        UInt8(ascii: "<"): "&lt;",
        UInt8(ascii: ">"): "&gt;",
    ]

    /// Stores an inline byte array to avoid the memory overhead of using `[UInt8]`.
    private struct InlineByteArray {
        private(set) var eightBytes: Int64 = 0
        private(set) var count: Int

        init(bytes: [UInt8]) {
            assert(bytes.count <= 8)
            self.count = bytes.count
            withUnsafeMutablePointer(to: &self) {
                let selfPointer = UnsafeMutableRawPointer($0)
                bytes.withUnsafeBytes { bytesPointer in
                    selfPointer.copyMemory(from: bytesPointer.baseAddress!, byteCount: bytes.count)
                }
            }
        }
    }

    private struct SixteenBytes {
        let firstEight: Int64 = 0
        let secondEight: Int64 = 0

        init() {}
    }

    /// Same as `htmlEscapeMap`, but stored as an array indexed from 0 to 255 to avoid dictionary lookups.
    /// In addition, we store `InlineByteArray`s instead of `String`s in order to avoid memory management overhead.
    /// If no escaping is required for a character, the character itself is stored.
    /// Using an array-typed lookup table is much faster than a dictionary-typed one or `if`-based branching.
    private static let htmlEscapeMapASCIIByteArray: [InlineByteArray] = (UInt8(0)...UInt8(255)).map { byte in
        if let escaped = String.htmlEscapeMap[byte] {
            return InlineByteArray(bytes: Array(escaped.utf8))
        } else {
            return InlineByteArray(bytes: [byte])
        }
    }

    /// Escapes HTML entities in a `String`.
    fileprivate func htmlEscaped() -> String {
        var expectedLength = 0
        // Using `withUnsafeBufferPointer` is minimally faster than calling `String.htmlEscapeMapASCIILengths[Int(character)]` for each character.
        String.htmlEscapeMapASCIIByteArray.withUnsafeBufferPointer { lengths in
            for character in utf8 {
                expectedLength += lengths[Int(character)].count
            }
        }

        guard expectedLength != utf8.count else {
            // Shortcut: no replacements necessary; skip them altogether.
            return self
        }

        func writeEscapedString(_ resultBytes: UnsafeMutableRawPointer) -> Void {
            var raw = resultBytes
            let end = raw + expectedLength
            for character in utf8 {
                var escaped = String.htmlEscapeMapASCIIByteArray[Int(character)]
                assert(raw + escaped.count <= end)
                raw.copyMemory(from: &escaped, byteCount: escaped.count)
                raw += escaped.count
            }
        }

        if expectedLength <= 15 {
            // Avoid the `Array<UInt8>` heap allocation for strings consisting
            // of at most 15 UTF-8 code units, where `String`'s small string
            // optimization avoids a memory allocation.
            // This provides another ~5x speedup compared to the "slow" path below.
            // Note: This might be slightly less efficient (but still correct,
            // and still faster than the slow path) for non-ASCII Strings on Swift 4.2.
            var resultData = SixteenBytes()
            return withUnsafeMutablePointer(to: &resultData) {
                let resultBytes = UnsafeMutableRawPointer($0)
                writeEscapedString(resultBytes)
                // Note: Byte 16 should always be zero to make sure the string is null-terminated.
                // This is ensured by `raw + escaped.count <= end = expectedLength <= 15` above.
                return String(cString: resultBytes.assumingMemoryBound(to: UInt8.self))
            }
        } else {
            var resultData = Array<UInt8>(repeating: 0, count: expectedLength)
            resultData.withUnsafeMutableBytes {
                writeEscapedString($0.baseAddress!)
            }

            // TODO: It might be possible to gain further improvements
            // by re-using the byte array allocated by `resultData`
            // to avoid copying the string's bytes here.
            return String(bytes: resultData, encoding: .utf8)! // Guaranteed to succeed.
        }
    }
}
