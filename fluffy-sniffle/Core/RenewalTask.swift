import Foundation

enum RepeatCycle: String, Codable, CaseIterable, Identifiable {
    case never, weekly, monthly, yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .never: return "Never"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

/// Raw values match `Calendar.component(.weekday, from:)` (1 = Sunday).
enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    static let mondayFirst: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    var shortLabel: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    var fullLabel: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}

enum ReminderOffset: String, Codable, CaseIterable, Identifiable, Comparable {
    case onTheDay, oneDay, twoDays, threeDays, oneWeek, twoWeeks, oneMonth, twoMonths

    var id: String { rawValue }

    var chipLabel: String {
        switch self {
        case .onTheDay: return "On the day"
        case .oneDay: return "1 day"
        case .twoDays: return "2 days"
        case .threeDays: return "3 days"
        case .oneWeek: return "1 week"
        case .twoWeeks: return "2 weeks"
        case .oneMonth: return "1 month"
        case .twoMonths: return "2 months"
        }
    }

    var dueText: String {
        switch self {
        case .onTheDay: return "Due today"
        case .oneDay: return "Due tomorrow"
        case .twoDays: return "Due in 2 days"
        case .threeDays: return "Due in 3 days"
        case .oneWeek: return "Due in 1 week"
        case .twoWeeks: return "Due in 2 weeks"
        case .oneMonth: return "Due in 1 month"
        case .twoMonths: return "Due in 2 months"
        }
    }

    func reminderDay(before day: Date, calendar: Calendar) -> Date {
        let component: Calendar.Component
        let value: Int
        switch self {
        case .onTheDay: component = .day; value = 0
        case .oneDay: component = .day; value = 1
        case .twoDays: component = .day; value = 2
        case .threeDays: component = .day; value = 3
        case .oneWeek: component = .day; value = 7
        case .twoWeeks: component = .day; value = 14
        case .oneMonth: component = .month; value = 1
        case .twoMonths: component = .month; value = 2
        }
        return calendar.date(byAdding: component, value: -value, to: day) ?? day
    }

    private var sortIndex: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    static func < (lhs: ReminderOffset, rhs: ReminderOffset) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }
}

enum CardTint: String, Codable, CaseIterable, Identifiable {
    case purple, green, yellow, blue, pink, teal

    var id: String { rawValue }
}

struct ProviderDetails: Codable, Hashable {
    var name = ""
    var policyNumber = ""
    var phone = ""
    var website = ""

    var isEmpty: Bool {
        [name, policyNumber, phone, website].allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

struct RenewalTask: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var iconName = "house.fill"
    var tint = CardTint.purple
    /// The date the user picked; each due date is `anchorDate + cyclesCompleted × repeatCycle`.
    /// Counting from a fixed anchor avoids drift (e.g. 31 Jan → 28 Feb → 28 Mar).
    var anchorDate: Date
    var cyclesCompleted = 0
    var repeatCycle = RepeatCycle.yearly
    /// When set, each due date moves back to the nearest earlier (or same) occurrence of this weekday.
    var preferredWeekday: Weekday?
    var reminderOffsets: Set<ReminderOffset> = [.oneWeek, .oneDay]
    var reminderHour = 9
    var reminderMinute = 0
    var provider = ProviderDetails()
    var lastPrice: Decimal?
    var previousPrice: Decimal?
    var notes = ""
    var isCompleted = false
    var createdAt = Date()
}
