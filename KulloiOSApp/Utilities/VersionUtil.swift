/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */
import Foundation

class VersionUtil {
    static var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
    }

    static var appBuild: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as! String
    }
}
