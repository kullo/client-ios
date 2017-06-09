/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import CoreGraphics

extension CGSize {
    static func / (left: CGSize, right: CGFloat) -> CGSize {
        return CGSize(width: left.width / right, height: left.height / right)
    }
}
