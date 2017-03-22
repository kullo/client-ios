/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import UIKit
import XCGLogger

class MoreEditTextViewController: UIViewController {
    
    // MARK: Properties

    var rowType: MoreViewController.RowType?
    @IBOutlet var editTextView: UITextView!

    // MARK: View lifecycle
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupKeyboardNotifcationListenerForScrollView(editTextView)

        if let rowType = self.rowType {
            switch rowType {
            case .footer:
                title = NSLocalizedString("Edit footer", comment: "")
                editTextView.text = KulloConnector.shared.getClientFooter()
                editTextView.isEditable = true
            case .masterKey:
                title = NSLocalizedString("MasterKey", comment: "")
                editTextView.text = KulloConnector.shared.getClientMasterKeyPem()
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

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        removeKeyboardNotificationListeners()
    }

}

extension MoreEditTextViewController: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        if let rowType = rowType {
            switch rowType {
            case .footer:
                KulloConnector.shared.setClientFooter(self.editTextView.text)
            default:
                break
            }
        }
    }
}
