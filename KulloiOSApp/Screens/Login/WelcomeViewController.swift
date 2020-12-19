/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import UIKit

class WelcomeViewController: UIViewController {
    @IBOutlet var openInboxButton: UIButton!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        openInboxButton.isEnabled = StorageManager.getAccounts().count > 0
    }

    @IBAction func openInboxTapped(_ sender: UIButton) {
        let chooseInboxVC = StoryboardUtil.instantiate(ChooseInboxTableViewController.self)
        navigationController?.pushViewController(chooseInboxVC, animated: true)
    }

    @IBAction func loginTapped(_ sender: UIButton) {
        let loginVC = StoryboardUtil.instantiate(LoginViewController.self)
        navigationController?.pushViewController(loginVC, animated: true)
    }

    @IBAction func registerTapped(_ sender: UIButton) {
        let generateKeysVC = StoryboardUtil.instantiate(GenerateKeysViewController.self)
        navigationController?.pushViewController(generateKeysVC, animated: true)
    }
}
