/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import Foundation
import TCMobileProvision

class FeatureDetection {

    static func isRunningOnSimulator() -> Bool {
        return TARGET_OS_SIMULATOR != 0
    }

    static func isRunningInPushSandbox() -> Bool {
        let bundle = Bundle.main
        guard
            let provisioningProfileUrl = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
            let provisioningProfileData = try? Data(contentsOf: provisioningProfileUrl),
            let provisioningProfile = TCMobileProvision(data: provisioningProfileData).dict,
            let entitlements = provisioningProfile["Entitlements"] as? [AnyHashable: Any],
            let apsEnvironment = entitlements["aps-environment"] as? String
            else {
                log.warning("FeatureDetection: Cannot read aps-environment entitlement")
                // AppStore downloads don't seem to have the .mobileprovision file
                return false
        }
        log.debug("aps-environment: \(apsEnvironment)")
        return apsEnvironment == "development"
    }

}
