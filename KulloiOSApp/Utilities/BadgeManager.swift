/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

class BadgeManager {

    func register() {
        KulloConnector.sharedInstance.addSessionEventsDelegate(self)
    }

    func unregister() {
        KulloConnector.sharedInstance.removeSessionEventsDelegate(self)
    }

    func update() {
        let unreadCount = KulloConnector.sharedInstance.getTotalUnread()
        UIApplication.shared.applicationIconBadgeNumber = Int(unreadCount)
    }
}

extension BadgeManager: SessionEventsDelegate {

    func sessionEventSessionCreated() {
        update()
    }

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
