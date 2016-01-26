/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import Foundation
import TCMobileProvision

class FeatureDetection {

    static func isRunningOnSimulator() -> Bool {
        return TARGET_OS_SIMULATOR != 0 as Int32
    }

    static func isRunningInPushSandbox() -> Bool {
        let bundle = NSBundle.mainBundle()
        guard
            let mobileProvisionUrl = bundle.URLForResource("embedded", withExtension: "mobileprovision"),
            let mobileProvision = TCMobileProvision.init(data: NSData.init(contentsOfURL: mobileProvisionUrl)),
            let entitlements = mobileProvision.dict["Entitlements"],
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
