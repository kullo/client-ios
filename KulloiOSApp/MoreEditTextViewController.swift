/* Copyright 2015 Kullo GmbH. All rights reserved. */

import UIKit
import XCGLogger

class MoreEditTextViewController: UIViewController {
    
    // MARK: Properties
    
    var cellType: MoreCellType = MoreCellType.Undefined
    @IBOutlet var editTextView: UITextView!

    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        switch cellType {
        case MoreCellType.Footer:
            self.title = NSLocalizedString("Edit footer", comment: "")
            self.editTextView.text = KulloConnector.sharedInstance.getClientFooter()
            self.editTextView.becomeFirstResponder()
            self.editTextView.editable = true
        default:
            self.title = NSLocalizedString("Edit text", comment: "")
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        setupKeyboardNotifcationListenerForScrollView(editTextView)
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
