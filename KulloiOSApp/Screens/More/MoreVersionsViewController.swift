/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import UIKit

class MoreVersionsViewController: UITableViewController {

    enum Section: Int {
        case app, components
    }

    let sectionTitles = [
        NSLocalizedString("App", comment: ""),
        NSLocalizedString("Libraries", comment: ""),
    ]

    let versions = KulloConnector.sharedInstance.getVersions()


    override func numberOfSections(in tableView: UITableView) -> Int {
        return sectionTitles.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTitles[section]
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {

        case .app:
            return 1

        case .components:
            return versions.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MoreVersionsCell", for: indexPath)
            as! MoreVersionsCell

        let version = versionForIndexPath(indexPath)
        cell.componentLabel.text = version.component
        cell.versionLabel.text = version.version
        return cell
    }

    func versionForIndexPath(_ indexPath: IndexPath) -> KulloConnector.VersionTuple {
        switch Section(rawValue: indexPath.section)! {

        case .app:
            let appVersion = "\(VersionUtil.appVersion) (Build \(VersionUtil.appBuild))"
            return KulloConnector.VersionTuple("Kullo for iOS", appVersion)

        case .components:
            return versions[indexPath.row]
        }
    }

}


class MoreVersionsCell: UITableViewCell {
    @IBOutlet var componentLabel: UILabel!
    @IBOutlet var versionLabel: UILabel!
}
