/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import XCTest

class InitialsTest: XCTestCase {

    let tests: [(input: String, expected: String)] = [
        // simple cases
        ("", ""),
        ("Foo", "F"),
        ("Foo Bar", "FB"),
        ("Foo 2", "F2"),

        // compound names
        ("Foo Abc-Def", "FA"),
        ("Foo de Abc-Def", "FA"),
        ("Foo -Bar", "FB"),

        // convert to uppercase
        ("foo", "F"),
        ("foo bar", "FB"),

        // respect non-ASCII letters
        ("Égalité ö", "ÉÖ"),

        // ignore emoji
        ("🐵", ""),
        ("🐵 Abc", "A"),
        ("🐵 Abc Def", "AD"),
        ("Abc 🐵Def", "AD"),

        // take first and last part
        ("Foo A Bar", "FB"),
        ("Foo A C Bar", "FB"),

        // ignore special characters
        ("Foo (2)", "F2"),
        ("Foo ()", "F"),

        // detect various forms of whitespace
        ("Foo  Bar", "FB"),
        ("Foo\tBar", "FB"),
        ("Foo\rBar", "FB"),
        ("Foo\nBar", "FB"),

        // three bytes
        ("朽", "朽"),
        ("A 朽", "A朽"),
        ("朽 A", "朽A"),

        // non-BMP characters (U+01D49E)
        ("𝒞", "𝒞"),
        ("A 𝒞", "A𝒞"),
        ("𝒞 A", "𝒞A"),
    ]

    func testGetInitialsForName() {
        for test in tests {
            XCTAssertEqual(InitialsUtil.getInitialsForName(test.input), test.expected)
        }
    }

}
