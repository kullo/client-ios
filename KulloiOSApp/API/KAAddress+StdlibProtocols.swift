/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

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
    open override var hashValue: Int {
        return description().hashValue
    }

    // CustomDebugStringConvertible
    open override var debugDescription: String {
        return "KAAdress(\(description()))"
    }
}
