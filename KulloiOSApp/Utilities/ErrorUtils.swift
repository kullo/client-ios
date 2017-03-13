/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import LibKullo

extension KANetworkError {
    var message: String {
        switch self {
        case .forbidden:
            return NSLocalizedString("network_error_forbidden", comment: "")
        case .protocol:
            return NSLocalizedString("network_error_protocol", comment: "")
        case .unauthorized:
            return NSLocalizedString("network_error_unauthorized", comment: "")
        case .server:
            return NSLocalizedString("network_error_server", comment: "")
        case .connection:
            return NSLocalizedString("network_error_connection", comment: "")
        case .unknown:
            return NSLocalizedString("network_error_unknown", comment: "")
        }
    }
}

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
