/* Copyright 2015 Kullo GmbH. All rights reserved. */

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
    
    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Configure the view for the selected state
    }
    
    func setCellType(cellType: MoreCellType) {
        self.cellType = cellType
        
        switch cellType {
        case .Address:
            let address = KulloConnector.sharedInstance.getClientAddress()
            cellTitle.text = NSLocalizedString("Address", comment: "")
            cellEditContent.placeholder = ""
            cellEditContent.text = address
            cellEditContent.userInteractionEnabled = false

        case .Name:
            let name = KulloConnector.sharedInstance.getClientName()
            cellTitle.text = NSLocalizedString("Name", comment: "")
            cellEditContent.placeholder = NSLocalizedString("Enter name", comment: "")
            cellEditContent.text = name
            cellEditContent.userInteractionEnabled = true

        case .Organization:
            let organization = KulloConnector.sharedInstance.getClientOrganization()
            cellTitle.text = NSLocalizedString("Organization", comment: "")
            cellEditContent.placeholder = NSLocalizedString("Enter organization", comment: "")
            cellEditContent.text = organization
            cellEditContent.userInteractionEnabled = true

        default: break
        }
    }

    @IBAction func textfieldEditingChanged(textField: UITextField) {
        if let text = textField.text, let cellType = self.cellType {
            switch cellType {
            case MoreCellType.Name:
                KulloConnector.sharedInstance.setClientName(text)
            case MoreCellType.Organization:
                KulloConnector.sharedInstance.setClientOrganization(text)
            default: break
            }
        }
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
}
