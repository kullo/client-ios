/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

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
