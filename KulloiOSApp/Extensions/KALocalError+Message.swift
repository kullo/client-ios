/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

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
