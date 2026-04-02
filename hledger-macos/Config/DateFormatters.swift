/// Shared date formatters to avoid recreating them repeatedly.

import Foundation

enum DateFormatters {
    static let yearMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    static let iso: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let displayMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    static let shortMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    /// Format a "yyyy-MM" string as "MMMM yyyy" (e.g., "March 2026").
    static func periodLabel(for period: String) -> String {
        guard let date = yearMonth.date(from: period) else { return period }
        return displayMonth.string(from: date)
    }

    /// Current month as "yyyy-MM".
    static var currentMonth: String {
        yearMonth.string(from: Date())
    }

    /// Today as "yyyy-MM-dd".
    static var today: String {
        iso.string(from: Date())
    }

    /// Adjust a "yyyy-MM" period by N months.
    static func adjustMonth(_ period: String, by months: Int) -> String {
        guard let date = yearMonth.date(from: period),
              let adjusted = Calendar.current.date(byAdding: .month, value: months, to: date) else { return period }
        return yearMonth.string(from: adjusted)
    }
}
