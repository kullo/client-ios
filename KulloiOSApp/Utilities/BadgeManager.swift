/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import UIKit

class BadgeManager {
    weak var connector: KulloConnector?

    func register(connector: KulloConnector) {
        self.connector = connector
        connector.addSessionEventsDelegate(self)
    }

    func unregister() {
        connector?.removeSessionEventsDelegate(self)
        self.connector = nil
    }

    func update() {
        if let unreadCount = connector?.getTotalUnread() {
            UIApplication.shared.applicationIconBadgeNumber = Int(unreadCount)
        }
    }
}

extension BadgeManager: SessionEventsDelegate {

    func sessionEventMessageAdded(_ convId: Int64, msgId: Int64) {
        update()
    }

    func sessionEventMessageRemoved(_ convId: Int64, msgId: Int64) {
        update()
    }

    func sessionEventMessageStateChanged(_ convId: Int64, msgId: Int64) {
        update()
    }
}
