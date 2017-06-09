/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import Foundation
import LibKullo

extension KAAddress {
    // from NSObject, also used for Equatable
    open override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? KAAddress else { return false }
        return self === other || self.toString() == other.toString()
    }

    // Hashable
    open override var hashValue: Int {
        return toString().hashValue
    }

    // CustomDebugStringConvertible
    open override var debugDescription: String {
        return "KAAdress(\(toString()))"
    }
}
