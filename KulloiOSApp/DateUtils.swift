/* Copyright 2015 Kullo GmbH. All rights reserved. */

import Foundation
import LibKullo

extension KADateTime {

    func formatWithSymbolicNames() -> String {
        let date = toNSDate()
        let calendar = NSCalendar.currentCalendar()

        if calendar.isDateInToday(date) {
            return NSDateFormatter.localizedStringFromDate(
                date,
                dateStyle: .NoStyle,
                timeStyle: .ShortStyle)

        } else if calendar.isDateInYesterday(date) {
            return NSLocalizedString("yesterday", comment: "")

        } else {
            let comparedWithToday = date.compare(
                KAConversations.emptyConversationTimestamp().toNSDate())
            if comparedWithToday == .OrderedSame {
                return NSLocalizedString("new", comment: "")
            }

            return NSDateFormatter.localizedStringFromDate(
                date,
                dateStyle: .ShortStyle,
                timeStyle: .NoStyle)
        }
    }

    func toNSDate() -> NSDate {
        let dateComponents = NSDateComponents()
        dateComponents.calendar = NSCalendar(identifier: NSCalendarIdentifierGregorian)
        dateComponents.year = Int(self.year)
        dateComponents.month = Int(self.month)
        dateComponents.day = Int(self.day)
        dateComponents.hour = Int(self.hour)
        dateComponents.minute = Int(self.minute)
        dateComponents.second = Int(self.second)
        dateComponents.timeZone = NSTimeZone(forSecondsFromGMT: Int(self.tzOffsetMinutes) * 60)

        if let date = dateComponents.date {
            return date
        } else {
            preconditionFailure("This KADateTime is invalid")
        }
    }
    
}
