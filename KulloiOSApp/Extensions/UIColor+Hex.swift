/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import UIKit

extension UIColor {
    convenience init(hex: String) {
        if let _ = hex.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) {
            var rgbValue: UInt32 = 0
            let scanner = Scanner(string: hex)
            scanner.scanLocation = 1  // skip "#"
            scanner.scanHexInt32(&rgbValue)

            self.init(
                red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                alpha: CGFloat(1.0)
            )

        } else {
            preconditionFailure("hex colors must have the format #RRGGBB")
        }
    }
}
