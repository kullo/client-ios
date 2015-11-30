/* Copyright 2015 Kullo GmbH. All rights reserved. */

import UIKit

extension UIViewController {
    
    func showWaitingDialog(title: String, message: String) -> UIAlertController {
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert);
        
        self.presentViewController(alert, animated: true, completion: nil);
        return alert
    }
    
    func showInfoDialog(title: String, message: String) -> UIAlertController {
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert);
        
        alert.addAction(AlertHelper.getAlertOKAction())
        
        self.presentViewController(alert, animated: true, completion: nil);
        return alert
    }
    
    func showConfirmationDialog(title: String, message: String, confirmationButtonText: String, handler: (action:UIAlertAction!) -> Void) -> UIAlertController {
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert);
        let confirmationAction = UIAlertAction(title: confirmationButtonText, style: .Destructive, handler: handler)
        
        alert.addAction(AlertHelper.getAlertCancelAction())
        alert.addAction(confirmationAction)
        
        self.presentViewController(alert, animated: true, completion: nil);
        return alert
    }
}

class AlertHelper {
    class func getAlertOKAction(handler: ((UIAlertAction) -> Void)? = nil) -> UIAlertAction {
        return UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .Default, handler: handler)
    }

    class func getAlertCancelAction() -> UIAlertAction {
        return UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .Cancel, handler: nil)
    }
}
