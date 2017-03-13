/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import UIKit

extension UIViewController {

    @discardableResult
    func showWaitingDialog(_ title: String, message: String) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        present(alert, animated: true, completion: nil)
        return alert
    }

    @discardableResult
    func showInfoDialog(_ title: String, message: String) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(AlertHelper.getAlertOKAction())
        present(alert, animated: true, completion: nil)
        return alert
    }

    @discardableResult
    func showConfirmationDialog(_ title: String, message: String, confirmationButtonText: String, handler: @escaping (_ action:UIAlertAction?) -> Void) -> UIAlertController {
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let confirmationAction = UIAlertAction(title: confirmationButtonText, style: .destructive, handler: handler)
        
        alert.addAction(AlertHelper.getAlertCancelAction())
        alert.addAction(confirmationAction)
        
        self.present(alert, animated: true, completion: nil)
        return alert
    }
}

class AlertHelper {
    class func getAlertOKAction(_ handler: ((UIAlertAction) -> Void)? = nil) -> UIAlertAction {
        return UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: handler)
    }

    class func getAlertCancelAction() -> UIAlertAction {
        return UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)
    }
}
