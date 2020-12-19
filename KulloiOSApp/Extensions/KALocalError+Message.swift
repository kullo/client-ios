/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import LibKullo

extension KALocalError {
    var message: String {
        switch self {
        case .fileTooBig:
            return NSLocalizedString("local_error_file_too_big", comment: "")
        case .filesystem:
            return NSLocalizedString("local_error_filesystem", comment: "")
        case .unknown:
            return NSLocalizedString("local_error_unknown", comment: "")
        }
    }
}
