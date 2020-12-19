/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import UIKit

class MoreActionTableViewCell: UITableViewCell {
    @IBOutlet var cellTitle: UILabel!
    @IBOutlet var cellContent: UILabel!

    var rowType: MoreViewController.RowType? {
        didSet {
            guard let rowType = rowType else { return }

            switch rowType {
            case .footer:
                let footer = KulloConnector.shared.getClientFooter()
                cellTitle.text = NSLocalizedString("Footer", comment: "")
                cellContent.text = footer
            case .plan:
                cellTitle.text = NSLocalizedString("Plan", comment: "")
                cellContent.text = accountInfo
            case .masterKey:
                cellTitle.text = NSLocalizedString("MasterKey", comment: "")
                cellContent.text = ""
            case .leaveInbox:
                cellTitle.text = NSLocalizedString("Leave inbox", comment: "")
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

    private var accountInfo: String {
        let content: String
        if let info = KulloConnector.shared.accountInfo {
            let storagePercentUsed = 100 * info.storageUsed!.doubleValue / info.storageQuota!.doubleValue
            let used = String.localizedStringWithFormat(
                NSLocalizedString("%d%% used", comment: ""),
                Int(storagePercentUsed)
            )
            content = "\(info.planName!) (\(used))"
        } else {
            content = ""
        }
        return content
    }
}
