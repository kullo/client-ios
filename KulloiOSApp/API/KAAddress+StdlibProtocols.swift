/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import Foundation
import LibKullo

extension KAAddress {
    // from NSObject, also used for Equatable
    open override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? KAAddress else { return false }
        if self === other { return true }

        return self.localPart == other.localPart
            && self.domainPart == other.domainPart
    }

    // Hashable
    open override var hash: Int {
        return description().hashValue
    }

    // CustomDebugStringConvertible
    open override var debugDescription: String {
        return "KAAdress(\(description()))"
    }
}
