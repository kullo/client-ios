/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */
import Foundation

class VersionUtil {
    static var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
    }

    static var appBuild: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as! String
    }
}
