/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import UIKit

extension UIColor {
    
    convenience init(hex: String) {
        if let _ = hex.rangeOfString("^#[0-9a-fA-F]{6}$", options: .RegularExpressionSearch) {
            var rgbValue: UInt32 = 0
            let scanner = NSScanner(string: hex)
            scanner.scanLocation = 1  // skip "#"
            scanner.scanHexInt(&rgbValue)

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
