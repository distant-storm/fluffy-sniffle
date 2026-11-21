import Foundation

struct PlannedReminder: Identifiable, Hashable {
    var id: String
    var taskID: UUID
    var offset: ReminderOffset
    var dueDate: Date
    var fireDate: Date
}

struct RenewalSchedule {
    var calendar: Calendar

    /// The unadjusted due date `cycleOffset` cycles after the current one (negative values look back).
    func nominalDate(for task: RenewalTask, cycleOffset: Int = 0) -> Date? {
        let anchor = calendar.startOfDay(for: task.anchorDate)
        let cycles = task.cyclesCompleted + cycleOffset
        switch task.repeatCycle {
        case .never:
            return cycleOffset == 0 ? anchor : nil
        case .weekly:
            return calendar.date(byAdding: .day, value: 7 * cycles, to: anchor)
        case .monthly:
            return calendar.date(byAdding: .month, value: cycles, to: anchor)
        case .yearly:
            return calendar.date(byAdding: .year, value: cycles, to: anchor)
        }
    }

    /// Moves `date` back to the closest `weekday` on or before it.
    func adjusted(_ date: Date, toWeekday weekday: Weekday?) -> Date {
        guard let weekday else { return date }
        let current = calendar.component(.weekday, from: date)
        let daysBack = (current - weekday.rawValue + 7) % 7
        return calendar.date(byAdding: .day, value: -daysBack, to: date) ?? date
    }

    func dueDate(for task: RenewalTask, cycleOffset: Int = 0) -> Date? {
        nominalDate(for: task, cycleOffset: cycleOffset).map { adjusted($0, toWeekday: task.preferredWeekday) }
    }

    func nextDueDate(for task: RenewalTask) -> Date {
        dueDate(for: task) ?? calendar.startOfDay(for: task.anchorDate)
    }

    func upcomingDueDates(for task: RenewalTask, count: Int) -> [Date] {
        (0..<max(count, 0)).compactMap { dueDate(for: task, cycleOffset: $0) }
    }

    /// Whole days from today until the next due date; negative when overdue.
    func daysUntilDue(_ task: RenewalTask, now: Date) -> Int {
        let today = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: today, to: nextDueDate(for: task)).day ?? 0
    }

    /// Fraction of time remaining in the current cycle: 1 at the start, 0 on the due date.
    func timeRemainingFraction(_ task: RenewalTask, now: Date) -> Double {
        let due = nextDueDate(for: task)
        let start = dueDate(for: task, cycleOffset: -1) ?? calendar.startOfDay(for: task.createdAt)
        let total = due.timeIntervalSince(start)
        guard total > 0 else { return now < due ? 1 : 0 }
        return min(max(due.timeIntervalSince(now) / total, 0), 1)
    }

    /// Repeating tasks move on one cycle; one-off tasks are marked complete.
    func renewed(_ task: RenewalTask, newPrice: Decimal?) -> RenewalTask {
        var updated = task
        if task.repeatCycle == .never {
            updated.isCompleted = true
        } else {
            updated.cyclesCompleted += 1
        }
        if let newPrice {
            updated.previousPrice = task.lastPrice
            updated.lastPrice = newPrice
        }
        return updated
    }

    func reminders(for task: RenewalTask, occurrences: Int) -> [PlannedReminder] {
        guard !task.isCompleted else { return [] }
        var result: [PlannedReminder] = []
        for cycleOffset in 0..<max(occurrences, 0) {
            guard let due = dueDate(for: task, cycleOffset: cycleOffset) else { break }
            for offset in task.reminderOffsets.sorted() {
                let day = offset.reminderDay(before: due, calendar: calendar)
                guard let fire = calendar.date(
                    bySettingHour: task.reminderHour, minute: task.reminderMinute, second: 0, of: day
                ) else { continue }
                result.append(PlannedReminder(
                    id: "\(task.id.uuidString)-\(task.cyclesCompleted + cycleOffset)-\(offset.rawValue)",
                    taskID: task.id,
                    offset: offset,
                    dueDate: due,
                    fireDate: fire
                ))
            }
        }
        return result
    }

    /// iOS keeps at most 64 pending local notifications per app, so only the soonest are planned.
    /// The app re-plans whenever it becomes active, topping the queue back up.
    func plan(tasks: [RenewalTask], after now: Date, occurrencesPerTask: Int = 6, limit: Int = 60) -> [PlannedReminder] {
        let upcoming = tasks
            .flatMap { reminders(for: $0, occurrences: occurrencesPerTask) }
            .filter { $0.fireDate > now }
            .sorted { $0.fireDate < $1.fireDate }
        return Array(upcoming.prefix(limit))
    }
}
