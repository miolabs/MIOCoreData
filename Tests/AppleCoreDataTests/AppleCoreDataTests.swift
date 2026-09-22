// Apple Core Data only: this target has no Linux counterpart.
#if canImport(CoreData) && !os(Linux)

import XCTest

final class AppleCoreDataTests: XCTestCase {
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        //XCTAssertEqual(MIOCoreData().text, "Hello, World!")
    }
}

#endif
