/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import UIKit

class WelcomeViewController: UIViewController {
    @IBOutlet var openInboxButton: UIButton!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        openInboxButton.isEnabled = StorageManager.getAccounts().count > 0
    }
}
