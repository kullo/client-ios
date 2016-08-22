/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

class BadgeManager {

    func register() {
        KulloConnector.sharedInstance.addSessionEventsDelegate(self)
    }

    func unregister() {
        KulloConnector.sharedInstance.removeSessionEventsDelegate(self)
    }

    func update() {
        let unreadCount = KulloConnector.sharedInstance.getTotalUnread()
        UIApplication.sharedApplication().applicationIconBadgeNumber = Int(unreadCount)
    }
}

extension BadgeManager: SessionEventsDelegate {

    func sessionEventSessionCreated() {
        update()
    }

    func sessionEventMessageAdded(convId: Int64, msgId: Int64) {
        update()
    }

    func sessionEventMessageRemoved(convId: Int64, msgId: Int64) {
        update()
    }

    func sessionEventMessageStateChanged(convId: Int64, msgId: Int64) {
        update()
    }
}