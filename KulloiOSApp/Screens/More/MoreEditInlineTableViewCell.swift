/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import UIKit

class MoreEditInlineTableViewCell: UITableViewCell {
    
    // MARK: Properties

    var rowType: MoreViewController.RowType? {
        didSet {
            guard let rowType = rowType else { return }

            switch rowType {
            case .address:
                let address = KulloConnector.shared.getClientAddress()
                cellTitle.text = NSLocalizedString("Address", comment: "")
                cellEditContent.placeholder = ""
                cellEditContent.text = address
                cellEditContent.isUserInteractionEnabled = false

            case .name:
                let name = KulloConnector.shared.getClientName()
                cellTitle.text = NSLocalizedString("Name", comment: "")
                cellEditContent.placeholder = NSLocalizedString("Enter name", comment: "")
                cellEditContent.text = name
                cellEditContent.isUserInteractionEnabled = true

            case .organization:
                let organization = KulloConnector.shared.getClientOrganization()
                cellTitle.text = NSLocalizedString("Organization", comment: "")
                cellEditContent.placeholder = NSLocalizedString("Enter organization", comment: "")
                cellEditContent.text = organization
                cellEditContent.isUserInteractionEnabled = true

            default: break
            }
        }
    }
    
    @IBOutlet var cellTitle: UILabel!
    @IBOutlet var cellEditContent: UITextField!
    
    override func awakeFromNib() {
        super.awakeFromNib()

        cellEditContent.delegate = self
    }

    @IBAction func textfieldEditingChanged(_ textField: UITextField) {
        if let rowType = rowType, let text = textField.text {
            switch rowType {
            case .name:
                KulloConnector.shared.setClientName(text)
            case .organization:
                KulloConnector.shared.setClientOrganization(text)
            default: break
            }
        }
    }
}

extension MoreEditInlineTableViewCell: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
