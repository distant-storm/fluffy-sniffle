import SwiftUI

enum CountdownText {
    static func phrase(for days: Int) -> String {
        switch days {
        case ..<(-1): return "\(-days) days late"
        case -1: return "1 day late"
        case 0: return "today"
        case 1: return "tomorrow"
        default: return "in \(days) days"
        }
    }

    static func badge(for days: Int) -> String {
        switch days {
        case ..<0: return "\(-days)D LATE"
        case 0: return "TODAY"
        case 1: return "1 DAY"
        default: return "\(days) DAYS"
        }
    }

    static func tint(for days: Int) -> CardTint {
        if days < 0 { return .pink }
        if days <= 7 { return .yellow }
        return .green
    }
}

struct CountdownBadge: View {
    let days: Int

    var body: some View {
        let tint = CountdownText.tint(for: days)
        Text(CountdownText.badge(for: days))
            .font(.pixel(.caption, weight: .black))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tint.soft))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(tint.strong, lineWidth: 2))
            .contentTransition(.numericText())
    }
}

extension RenewalTask {
    func repeatSummary() -> String {
        var text = repeatCycle == .never ? "One-off" : "Repeats \(repeatCycle.label.lowercased())"
        if let preferredWeekday {
            text += " · \(preferredWeekday.shortLabel) before"
        }
        return text
    }

    func reminderSummary() -> String? {
        guard !reminderOffsets.isEmpty else { return nil }
        return reminderOffsets.sorted().reversed().map(\.chipLabel).joined(separator: ", ")
    }
}

struct TaskCardView: View {
    @Environment(TaskStore.self) var store
    let task: RenewalTask

    var body: some View {
        let now = Date()
        let due = store.schedule.nextDueDate(for: task)
        let days = store.schedule.daysUntilDue(task, now: now)

        PixelCard(
            title: task.title,
            icon: task.iconName,
            tint: task.tint,
            trailing: task.isCompleted ? "Done ✓" : nil
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(due.cardFormat)
                            .font(.pixel(.headline, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text(task.repeatSummary().uppercased())
                            .font(.pixel(.caption2, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer(minLength: 4)
                    if !task.isCompleted {
                        CountdownBadge(days: days)
                    }
                }

                if !task.isCompleted {
                    HStack(spacing: 8) {
                        Text("TIME")
                            .font(.pixel(.caption2, weight: .bold))
                            .foregroundStyle(Theme.inkSoft)
                        SegmentBar(fraction: store.schedule.timeRemainingFraction(task, now: now))
                    }
                }

                if !task.provider.name.isEmpty || task.lastPrice != nil {
                    HStack(spacing: 6) {
                        if !task.provider.name.isEmpty {
                            Image(systemName: "building.2.fill")
                                .font(.caption)
                                .foregroundStyle(task.tint.strong)
                            Text(task.provider.name)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        if let price = task.lastPrice {
                            Text(PriceFormat.display(price))
                                .fontWeight(.bold)
                        }
                    }
                    .font(.pixel(.footnote))
                    .foregroundStyle(Theme.ink)
                }

                if !task.isCompleted, let reminders = task.reminderSummary() {
                    HStack(spacing: 6) {
                        Image(systemName: "bell.fill")
                            .foregroundStyle(CardTint.yellow.strong)
                        Text(reminders.uppercased())
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .font(.pixel(.caption2, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .opacity(task.isCompleted ? 0.7 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens details")
    }
}
