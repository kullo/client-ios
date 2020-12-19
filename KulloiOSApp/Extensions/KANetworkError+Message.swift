/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

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
