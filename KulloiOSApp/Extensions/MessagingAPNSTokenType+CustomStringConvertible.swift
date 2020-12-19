/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */
import Firebase

extension MessagingAPNSTokenType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .prod: return "prod"
        case .sandbox: return "sandbox"
        case .unknown: return "unknown"
        }
    }
}
