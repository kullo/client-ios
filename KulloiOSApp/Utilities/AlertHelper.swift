/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import UIKit

class AlertHelper {
    static func getAlertOKAction(_ handler: ((UIAlertAction) -> Void)? = nil) -> UIAlertAction {
        return UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: handler)
    }

    static func getAlertCancelAction() -> UIAlertAction {
        return UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)
    }
}
