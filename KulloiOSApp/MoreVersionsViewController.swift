/* Copyright 2015 Kullo GmbH. All rights reserved. */

import UIKit

class MoreVersionsViewController: UITableViewController {

    enum Section: Int {
        case App, Components
    }

    let sectionTitles = [
        NSLocalizedString("App", comment: ""),
        NSLocalizedString("Libraries", comment: ""),
    ]

    let versions = KulloConnector.sharedInstance.getVersions()


    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return sectionTitles.count
    }

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sectionTitles[section]
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {

        case .App:
            return 1

        case .Components:
            return versions.count
        }
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("MoreVersionsCell", forIndexPath: indexPath)
            as! MoreVersionsCell

        let version = versionForIndexPath(indexPath)
        cell.componentLabel.text = version.component
        cell.versionLabel.text = version.version
        return cell
    }

    func versionForIndexPath(indexPath: NSIndexPath) -> KulloConnector.VersionTuple {
        switch Section(rawValue: indexPath.section)! {

        case .App:
            let appVersion = "\(KulloConnector.getAppVersion()) (Build \(KulloConnector.getAppBuild()))"
            return KulloConnector.VersionTuple("Kullo for iOS", appVersion)

        case .Components:
            return versions[indexPath.row]
        }
    }

}


class MoreVersionsCell: UITableViewCell {
    @IBOutlet var componentLabel: UILabel!
    @IBOutlet var versionLabel: UILabel!
}
