/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import UIKit

class PortraitNavigationController: UINavigationController {

    override func shouldAutorotate() -> Bool {
        return false
    }

    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .Portrait
    }

}