import Foundation

extension Calendar {
    static let utcGregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    static func currentWeekIntervalInUTC(referenceDate: Date = Date()) -> DateInterval {
        Calendar.utcGregorian.dateInterval(of: .weekOfYear, for: referenceDate)
            ?? DateInterval(start: referenceDate, duration: 7 * 24 * 60 * 60)
    }

    func date(in interval: DateInterval, weekday: Int, hour: Int, minute: Int) -> Date {
        let weekStart = interval.start
        let startWeekday = component(.weekday, from: weekStart)
        let dayOffset = (weekday - startWeekday + 7) % 7

        return date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: self.date(byAdding: .day, value: dayOffset, to: weekStart) ?? weekStart
        ) ?? weekStart
    }
}
