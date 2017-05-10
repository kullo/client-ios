/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import XCGLogger

let log: XCGLogger = {
    // manually setup logger which uses NSLog instead of print so that messages show up on production build
    let log = XCGLogger(identifier: "kulloLogger", includeDefaultDestinations: false)
    let systemDestination = AppleSystemLogDestination(owner: log)
    systemDestination.outputLevel = .debug
    systemDestination.showLogIdentifier = false
    systemDestination.showFunctionName = true
    systemDestination.showThreadName = true
    systemDestination.showLevel = true
    systemDestination.showFileName = true
    systemDestination.showLineNumber = true
    systemDestination.showDate = true
    log.add(destination: systemDestination)
    return log
}()
