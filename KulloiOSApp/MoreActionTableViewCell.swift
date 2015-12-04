/* Copyright 2015 Kullo GmbH. All rights reserved. */

import UIKit

class MoreActionTableViewCell: UITableViewCell {
    @IBOutlet var cellTitle: UILabel!
    @IBOutlet var cellContent: UILabel!

    func setCellType(cellType: MoreCellType) {
        switch cellType {
        case .Footer:
            let footer = KulloConnector.sharedInstance.getClientFooter()
            cellTitle.text = NSLocalizedString("Footer", comment: "")
            cellContent.text = footer
        case .MasterKey:
            cellTitle.text = NSLocalizedString("MasterKey", comment: "")
            cellContent.text = ""
        case .Logout:
            cellTitle.text = NSLocalizedString("Logout", comment: "")
            cellContent.text = ""
        case .Version:
            cellTitle.text = NSLocalizedString("Version", comment: "")
            cellContent.text = KulloConnector.getAppVersion()
        case .About:
            cellTitle.text = NSLocalizedString("About Kullo", comment: "")
            cellContent.text = ""
        case .Website:
            cellTitle.text = NSLocalizedString("Web", comment: "")
            cellContent.text = kulloWebsiteAddress
        case .Licenses:
            cellTitle.text = NSLocalizedString("Software licenses", comment: "")
            cellContent.text = ""
        case .Feedback:
            cellTitle.text = NSLocalizedString("Feedback", comment: "")
            cellContent.text = ""
        default: break
        }
    }

}
