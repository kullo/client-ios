/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import Foundation
import LibKullo

extension KADateTime {

    func formatWithDateAndTime() -> String {
        return DateFormatter.localizedString(
            from: toDate(),
            dateStyle: .short,
            timeStyle: .short)
    }

    func formatWithSymbolicNames() -> String {
        let date = toDate()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            // no date, only time
            return DateFormatter.localizedString(
                from: date,
                dateStyle: .none,
                timeStyle: .short)

        } else if calendar.isDateInYesterday(date) {
            // "yesterday"
            return NSLocalizedString("yesterday", comment: "")

        } else {
            // only date, no time; if empty conversation: "new"
            let comparedWithToday = date.compare(
                KAConversations.emptyConversationTimestamp().toDate())
            if comparedWithToday == .orderedSame {
                return NSLocalizedString("new", comment: "")
            }

            return DateFormatter.localizedString(
                from: date,
                dateStyle: .short,
                timeStyle: .none)
        }
    }

    func toDate() -> Date {
        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        dateComponents.year = Int(self.year)
        dateComponents.month = Int(self.month)
        dateComponents.day = Int(self.day)
        dateComponents.hour = Int(self.hour)
        dateComponents.minute = Int(self.minute)
        dateComponents.second = Int(self.second)
        dateComponents.timeZone = TimeZone(secondsFromGMT: Int(self.tzOffsetMinutes) * 60)

        if let date = dateComponents.date {
            return date
        } else {
            preconditionFailure("This KADateTime is invalid")
        }
    }
    
}
