/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import Foundation
import LibKullo

extension KAMessagesSearchResult {
    func renderSnippet(normalFont: UIFont, highlightFont: UIFont) -> NSAttributedString {
        let openTag = "(" + boundary + ")"
        let closeTag = "(/" + boundary + ")"

        let parts = snippet
            .replacingOccurrences(of: closeTag, with: openTag)
            .components(separatedBy: openTag)

        let result = NSMutableAttributedString()
        for (index, part) in parts.enumerated() {
            let isHighlighted = index % 2 == 1
            result.append(
                NSAttributedString(
                    string: part,
                    attributes: [.font: isHighlighted ? highlightFont : normalFont]
                )
            )
        }
        return result
    }
}
