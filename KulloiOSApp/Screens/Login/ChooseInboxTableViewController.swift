/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import LibKullo
import UIKit

class ChooseInboxTableViewController: UITableViewController {
    private static let cellReuseIdentifier = "ChooseInboxTableViewCell"
    private static let splashSegue = "ChooseInboxSplashSegue"

    private var accounts = [KAAddress]()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        accounts = StorageManager.getAccounts()
    }

    //MARK: - UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accounts.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ChooseInboxTableViewController.cellReuseIdentifier,
            for: indexPath)
        cell.textLabel?.text = accounts[indexPath.row].description()
        return cell
    }

    //MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        KulloConnector.shared.prepareLogin(accounts[indexPath.row])
        performSegue(withIdentifier: ChooseInboxTableViewController.splashSegue, sender: self)
    }
}
