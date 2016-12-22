/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import UIKit
import XCGLogger

class MoreEditTextViewController: UIViewController {
    
    // MARK: Properties
    
    var cellType: MoreCellType?
    @IBOutlet var editTextView: UITextView!

    // MARK: View lifecycle
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupKeyboardNotifcationListenerForScrollView(editTextView)

        if let cellType = self.cellType {
            switch cellType {
            case .footer:
                title = NSLocalizedString("Edit footer", comment: "")
                editTextView.text = KulloConnector.sharedInstance.getClientFooter()
                editTextView.isEditable = true
            case .masterKey:
                title = NSLocalizedString("MasterKey", comment: "")
                editTextView.text = KulloConnector.sharedInstance.getClientMasterKeyPem()
                editTextView.isEditable = false
                editTextView.font = fontMasterKey
            default:
                title = NSLocalizedString("Edit text", comment: "")
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if editTextView.isEditable {
            editTextView.becomeFirstResponder()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        removeKeyboardNotificationListeners()
    }

}

extension MoreEditTextViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        KulloConnector.sharedInstance.setClientFooter(self.editTextView.text)
    }
}
