import XCTest

extension RouteDocsTests {
    static let __allTests = [
        ("testExample", testExample),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(RouteDocsTests.__allTests),
    ]
}
#endif
