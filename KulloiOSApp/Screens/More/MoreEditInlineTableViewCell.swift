/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import UIKit

class MoreEditInlineTableViewCell: UITableViewCell, UITextFieldDelegate {
    
    // MARK: Properties
    
    var cellType: MoreCellType?
    
    @IBOutlet var cellTitle: UILabel!
    @IBOutlet var cellEditContent: UITextField!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        cellEditContent.delegate = self
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
    func setCellType(_ cellType: MoreCellType) {
        self.cellType = cellType
        
        switch cellType {
        case .address:
            let address = KulloConnector.sharedInstance.getClientAddress()
            cellTitle.text = NSLocalizedString("Address", comment: "")
            cellEditContent.placeholder = ""
            cellEditContent.text = address
            cellEditContent.isUserInteractionEnabled = false

        case .name:
            let name = KulloConnector.sharedInstance.getClientName()
            cellTitle.text = NSLocalizedString("Name", comment: "")
            cellEditContent.placeholder = NSLocalizedString("Enter name", comment: "")
            cellEditContent.text = name
            cellEditContent.isUserInteractionEnabled = true

        case .organization:
            let organization = KulloConnector.sharedInstance.getClientOrganization()
            cellTitle.text = NSLocalizedString("Organization", comment: "")
            cellEditContent.placeholder = NSLocalizedString("Enter organization", comment: "")
            cellEditContent.text = organization
            cellEditContent.isUserInteractionEnabled = true

        default: break
        }
    }

    @IBAction func textfieldEditingChanged(_ textField: UITextField) {
        if let text = textField.text, let cellType = self.cellType {
            switch cellType {
            case MoreCellType.name:
                KulloConnector.sharedInstance.setClientName(text)
            case MoreCellType.organization:
                KulloConnector.sharedInstance.setClientOrganization(text)
            default: break
            }
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
}
