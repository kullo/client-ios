/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import Foundation
import LibKullo

extension KADateTime {

    func formatWithDateAndTime() -> String {
        return NSDateFormatter.localizedStringFromDate(
            toNSDate(),
            dateStyle: .ShortStyle,
            timeStyle: .ShortStyle)
    }

    func formatWithSymbolicNames() -> String {
        let date = toNSDate()
        let calendar = NSCalendar.currentCalendar()

        if calendar.isDateInToday(date) {
            // no date, only time
            return NSDateFormatter.localizedStringFromDate(
                date,
                dateStyle: .NoStyle,
                timeStyle: .ShortStyle)

        } else if calendar.isDateInYesterday(date) {
            // "yesterday"
            return NSLocalizedString("yesterday", comment: "")

        } else {
            // only date, no time; if empty conversation: "new"
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
