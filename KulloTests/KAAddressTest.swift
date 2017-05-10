/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import LibKullo
import XCTest

class KAAddressTest: XCTestCase {
    let uutA1 = KAAddress.create("a#example.com")!
    let uutA2 = KAAddress.create("a#example.com")!
    let uutB = KAAddress.create("b#example.com")!

    func testEqualityOperator() {
        XCTAssert(uutA1 == uutA2)
        XCTAssertFalse(uutA1 == uutB)
    }

    func testInequalityOperator() {
        XCTAssertFalse(uutA1 != uutA2)
        XCTAssert(uutA1 != uutB)
    }

    func testNSObjectIsEqual() {
        XCTAssert(uutA1.isEqual(uutA2))
        XCTAssertFalse(uutA1.isEqual(uutB))
    }

    func testHashValue() {
        XCTAssertEqual(uutA1.hashValue, uutA2.hashValue)

        // Must not be the case, but accidental equality is extemely unlikely
        XCTAssertNotEqual(uutA1.hashValue, uutB.hashValue)
    }
}
