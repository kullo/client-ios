/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import UIKit

class MoreVersionsViewController: UITableViewController {

    private enum Section: Int {
        case app, components

        static let count = 2

        var title: String {
            switch self {
            case .app: return NSLocalizedString("App", comment: "")
            case .components: return NSLocalizedString("Libraries", comment: "")
            }
        }

        var count: Int {
            switch self {
            case .app: return 1
            case .components: return MoreVersionsViewController.versions.count
            }
        }
    }

    private static let versions = KulloConnector.sharedInstance.getVersions()

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)!.title
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Section(rawValue: section)!.count
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
            return MoreVersionsViewController.versions[indexPath.row]
        }
    }
}

class MoreVersionsCell: UITableViewCell {
    @IBOutlet var componentLabel: UILabel!
    @IBOutlet var versionLabel: UILabel!
}
