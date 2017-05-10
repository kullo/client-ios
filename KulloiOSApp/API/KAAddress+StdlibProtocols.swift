import Foundation
import LibKullo

extension KAAddress {
    // Equatable
    static func == (lhs: KAAddress, rhs: KAAddress) -> Bool {
        if lhs === rhs { return true }
        return lhs.isEqual(to: rhs)
    }

    // from NSObject, for Objective-C compatibility
    open override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? KAAddress else { return false }
        return self == other
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
