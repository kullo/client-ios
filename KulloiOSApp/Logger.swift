/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import SwiftyBeaver

let log = SwiftyBeaver.self

func setupLogger() {
    let console = ConsoleDestination()
    log.addDestination(console)

    console.useNSLog = true
    console.minLevel = .debug

    #if DEBUG
    console.asynchronously = false
    #endif
}
