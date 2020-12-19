/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

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
