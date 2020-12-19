/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import UIKit

extension UILabel {
    var isTruncated: Bool {
        guard let text = text as NSString? else { return false }

        let drawingContext = NSStringDrawingContext()
        drawingContext.minimumScaleFactor = minimumScaleFactor

        let necessarySize = text.boundingRect(
            with: CGSize(width: frame.width, height: CGFloat.greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: [.font: font],
            context: drawingContext
        )
        return necessarySize.height > frame.height
    }
}
