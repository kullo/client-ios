/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import UIKit

extension UIImageView {
    func showAsCircle() {
        self.layer.borderWidth = 0.0
        self.layer.masksToBounds = false
        self.layer.cornerRadius = self.frame.size.width / 2
        self.clipsToBounds = true
    }
}
