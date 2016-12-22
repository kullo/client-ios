/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import UIKit

class MoreActionTableViewCell: UITableViewCell {
    @IBOutlet var cellTitle: UILabel!
    @IBOutlet var cellContent: UILabel!

    func setCellType(_ cellType: MoreCellType) {
        switch cellType {
        case .footer:
            let footer = KulloConnector.sharedInstance.getClientFooter()
            cellTitle.text = NSLocalizedString("Footer", comment: "")
            cellContent.text = footer
        case .masterKey:
            cellTitle.text = NSLocalizedString("MasterKey", comment: "")
            cellContent.text = ""
        case .logout:
            cellTitle.text = NSLocalizedString("Logout", comment: "")
            cellContent.text = ""
        case .version:
            cellTitle.text = NSLocalizedString("Version", comment: "")
            cellContent.text = VersionUtil.appVersion
        case .about:
            cellTitle.text = NSLocalizedString("About Kullo", comment: "")
            cellContent.text = ""
        case .website:
            cellTitle.text = NSLocalizedString("Web", comment: "")
            cellContent.text = kulloWebsiteAddress
        case .licenses:
            cellTitle.text = NSLocalizedString("Software licenses", comment: "")
            cellContent.text = ""
        case .feedback:
            cellTitle.text = NSLocalizedString("Feedback", comment: "")
            cellContent.text = ""
        default: break
        }
    }

}
