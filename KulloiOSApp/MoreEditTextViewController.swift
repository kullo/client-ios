/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import UIKit
import XCGLogger

class MoreEditTextViewController: UIViewController {
    
    // MARK: Properties
    
    var cellType: MoreCellType?
    @IBOutlet var editTextView: UITextView!

    // MARK: View lifecycle
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        setupKeyboardNotifcationListenerForScrollView(editTextView)

        if let cellType = self.cellType {
            switch cellType {
            case .Footer:
                title = NSLocalizedString("Edit footer", comment: "")
                editTextView.text = KulloConnector.sharedInstance.getClientFooter()
                editTextView.editable = true
            case .MasterKey:
                title = NSLocalizedString("MasterKey", comment: "")
                editTextView.text = KulloConnector.sharedInstance.getClientMasterKeyPem()
                editTextView.editable = false
                editTextView.font = fontMasterKey
            default:
                title = NSLocalizedString("Edit text", comment: "")
            }
        }
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        if editTextView.editable {
            editTextView.becomeFirstResponder()
        }
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)

        removeKeyboardNotificationListeners()
    }

}

extension MoreEditTextViewController : UITextViewDelegate {
    func textViewDidChange(textView: UITextView) {
        KulloConnector.sharedInstance.setClientFooter(self.editTextView.text)
    }
}
