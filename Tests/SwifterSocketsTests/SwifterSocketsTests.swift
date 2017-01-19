import XCTest
@testable import SwifterSockets

class SwifterSocketsTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(SwifterSockets().text, "Hello, World!")
    }


    static var allTests : [(String, (SwifterSocketsTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
