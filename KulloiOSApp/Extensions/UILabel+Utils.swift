/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

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
