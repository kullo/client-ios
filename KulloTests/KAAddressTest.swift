/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import LibKullo
import XCTest

class KAAddressTest: XCTestCase {
    let uutA1 = KAAddressHelpers.create("a#example.com")!
    let uutA2 = KAAddressHelpers.create("a#example.com")!
    let uutB = KAAddressHelpers.create("b#example.com")!

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
