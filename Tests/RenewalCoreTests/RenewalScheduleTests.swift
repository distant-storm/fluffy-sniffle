import XCTest
@testable import RenewalCore

final class RenewalScheduleTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    private var schedule: RenewalSchedule { RenewalSchedule(calendar: calendar) }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func task(
        _ anchor: Date,
        repeat cycle: RepeatCycle = .yearly,
        weekday: Weekday? = nil,
        reminders: Set<ReminderOffset> = []
    ) -> RenewalTask {
        RenewalTask(
            title: "Home insurance",
            anchorDate: anchor,
            repeatCycle: cycle,
            preferredWeekday: weekday,
            reminderOffsets: reminders,
            createdAt: date(2025, 1, 1)
        )
    }

    func testYearlyRenewalOnSundayMovesBackToPreferredWednesday() {
        // 14 Mar 2027 is a Sunday; the Wednesday before is 10 Mar 2027.
        let renewal = task(date(2026, 3, 14), weekday: .wednesday)
        XCTAssertEqual(schedule.dueDate(for: renewal, cycleOffset: 1), date(2027, 3, 10))
    }

    func testPreferredWeekdayKeepsDateThatAlreadyMatches() {
        // 10 Mar 2027 is a Wednesday.
        let renewal = task(date(2027, 3, 10), weekday: .wednesday)
        XCTAssertEqual(schedule.nextDueDate(for: renewal), date(2027, 3, 10))
    }

    func testPreferredWeekdayNeverMovesForward() {
        // 9 Mar 2027 is a Tuesday, so the previous Wednesday is 6 days earlier.
        let renewal = task(date(2027, 3, 9), weekday: .wednesday)
        XCTAssertEqual(schedule.nextDueDate(for: renewal), date(2027, 3, 3))
    }

    func testMonthlyRepeatDoesNotDriftAfterShortMonths() {
        var renewal = task(date(2027, 1, 31), repeat: .monthly)
        renewal = schedule.renewed(renewal, newPrice: nil)
        XCTAssertEqual(schedule.nextDueDate(for: renewal), date(2027, 2, 28))
        renewal = schedule.renewed(renewal, newPrice: nil)
        XCTAssertEqual(schedule.nextDueDate(for: renewal), date(2027, 3, 31))
    }

    func testWeeklyRepeat() {
        let renewal = task(date(2027, 3, 1), repeat: .weekly)
        XCTAssertEqual(
            schedule.upcomingDueDates(for: renewal, count: 3),
            [date(2027, 3, 1), date(2027, 3, 8), date(2027, 3, 15)]
        )
    }

    func testOneOffTaskHasSingleDueDateAndCompletesWhenRenewed() {
        let renewal = task(date(2027, 3, 1), repeat: .never)
        XCTAssertEqual(schedule.upcomingDueDates(for: renewal, count: 3), [date(2027, 3, 1)])
        let done = schedule.renewed(renewal, newPrice: nil)
        XCTAssertTrue(done.isCompleted)
        XCTAssertTrue(schedule.reminders(for: done, occurrences: 3).isEmpty)
    }

    func testRenewingRecordsNewAndPreviousPrice() {
        var renewal = task(date(2027, 3, 1))
        renewal.lastPrice = Decimal(string: "312.40")
        let updated = schedule.renewed(renewal, newPrice: Decimal(string: "340"))
        XCTAssertEqual(updated.previousPrice, Decimal(string: "312.40"))
        XCTAssertEqual(updated.lastPrice, Decimal(string: "340"))
        XCTAssertEqual(schedule.nextDueDate(for: updated), date(2028, 3, 1))
    }

    func testRemindersFireBeforeAdjustedDueDateAtChosenTime() {
        var renewal = task(date(2027, 3, 14), weekday: .wednesday, reminders: [.oneDay, .oneWeek, .oneMonth])
        renewal.reminderHour = 8
        renewal.reminderMinute = 30
        let fireDates = schedule.reminders(for: renewal, occurrences: 1).map(\.fireDate)
        // Due date moves to Wed 10 Mar 2027.
        XCTAssertEqual(fireDates, [date(2027, 3, 9, 8, 30), date(2027, 3, 3, 8, 30), date(2027, 2, 10, 8, 30)])
    }

    func testPlanSkipsPastRemindersSortsAndRespectsLimit() {
        let now = date(2027, 3, 5, 12)
        let renewal = task(date(2027, 3, 10), repeat: .weekly, reminders: [.onTheDay, .oneWeek])
        let plan = schedule.plan(tasks: [renewal], after: now, occurrencesPerTask: 3, limit: 4)
        // Due 10, 17, 24 Mar. "1 week before 10 Mar" (3 Mar) has passed; each later
        // "1 week before" lands on the previous due date. The 5th reminder (24 Mar) is cut by the limit.
        XCTAssertEqual(plan.map(\.fireDate), [
            date(2027, 3, 10, 9), date(2027, 3, 10, 9), date(2027, 3, 17, 9), date(2027, 3, 17, 9),
        ])
        XCTAssertEqual(Set(plan.map(\.id)).count, plan.count)
    }

    func testDaysUntilDueIsNegativeWhenOverdue() {
        let renewal = task(date(2027, 3, 10), repeat: .never)
        XCTAssertEqual(schedule.daysUntilDue(renewal, now: date(2027, 3, 8, 18)), 2)
        XCTAssertEqual(schedule.daysUntilDue(renewal, now: date(2027, 3, 12, 9)), -2)
    }
}
