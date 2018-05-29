/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

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
