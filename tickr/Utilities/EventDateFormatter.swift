import Foundation

enum EventDateFormatter {
    static func dayString(from date: Date, useUTC: Bool) -> String {
        dayFormatter(useUTC: useUTC).string(from: date)
    }

    static func timeString(from date: Date, useUTC: Bool, use24HourTime: Bool) -> String {
        timeFormatter(useUTC: useUTC, use24HourTime: use24HourTime).string(from: date)
    }

    private static func dayFormatter(useUTC: Bool) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.timeZone = useUTC ? .gmt : .current
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }

    private static func timeFormatter(useUTC: Bool, use24HourTime: Bool) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.timeZone = useUTC ? .gmt : .current
        formatter.dateStyle = .none
        // Use a fixed POSIX locale so the 12/24-hour toggle is not overridden by device locale defaults.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = use24HourTime ? "HH:mm" : "h:mm a"
        return formatter
    }
}
