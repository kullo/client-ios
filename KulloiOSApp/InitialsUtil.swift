//
//  InitialsUtil.swift
//  KulloiOSApp
//
//  Created by Daniel on 22.08.16.
//  Copyright © 2016 Kullo GmbH. All rights reserved.
//

import Foundation

class InitialsUtil {

    static func getInitialsForName(name: String) -> String {
        // match all words, beginning with a letter or a digit (alnum + (word|-)*)
        let wordRegex = try! NSRegularExpression(pattern: "[:alnum:](?:-|\\w)*", options: .UseUnicodeWordBoundaries)
        let name = name.uppercaseString as NSString
        let matches = wordRegex.matchesInString(name as String, options: [], range: NSRange(location: 0, length: name.length))

        let initialFromNamePart = { (match: NSTextCheckingResult) in
            name.substringWithRange(match.range).characters.first!
        }

        guard let first = matches.first, last = matches.last else { return "" }
        if first == last {
            return String(initialFromNamePart(first))
        } else {
            return String(initialFromNamePart(first)) + String(initialFromNamePart(last))
        }
    }
}