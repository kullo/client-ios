/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import UIKit

class MoreEditTextViewController: UIViewController {
    var rowType: MoreViewController.RowType?
    private let editTextView = UITextView()

    override func loadView() {
        view = editTextView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        editTextView.delegate = self
        editTextView.keyboardDismissMode = .interactive
        editTextView.font = UIFont.preferredFont(forTextStyle: .body)
    }

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
