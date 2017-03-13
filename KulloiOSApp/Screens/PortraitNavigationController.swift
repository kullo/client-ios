/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import UIKit

class PortraitNavigationController: UINavigationController {

    override var shouldAutorotate: Bool {
        return false
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

}
