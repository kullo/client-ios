import Foundation

class VersionUtil {
    static var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
    }

    static var appBuild: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as! String
    }
}
