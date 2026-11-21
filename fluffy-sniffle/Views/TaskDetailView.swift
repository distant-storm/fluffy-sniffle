import SwiftUI

struct TaskDetailView: View {
    let taskID: UUID

    @Environment(TaskStore.self) var store
    @Environment(\.dismiss) var dismiss

    @State var showingEditor = false
    @State var showingRenew = false
    @State var confirmingDelete = false
    @State var newPriceText = ""
    @State var celebration = 0

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if let task = store.task(withID: taskID) {
                ScrollView {
                    VStack(spacing: 16) {
                        HeroCard(task: task)
                        DueCard(task: task)
                        RemindersCard(task: task)
                        if !task.provider.isEmpty {
                            ProviderCard(provider: task.provider, tint: task.tint)
                        }
                        if task.lastPrice != nil {
                            PriceCard(task: task)
                        }
                        if !task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            PixelCard(title: "Notes", icon: "note.text", tint: .teal) {
                                Text(task.notes)
                                    .font(.pixel(.footnote))
                                    .foregroundStyle(Theme.ink)
                                    .textSelection(.enabled)
                            }
                        }
                        actions(for: task)
                    }
                    .padding(16)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: task)
                }
                .scrollIndicators(.hidden)
            }

            CelebrationView(trigger: celebration)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showingEditor = true }
                    .font(.pixel(.body, weight: .bold))
                    .disabled(store.task(withID: taskID) == nil)
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let task = store.task(withID: taskID) {
                TaskEditorView(existing: task)
            }
        }
        .alert("Mark as renewed?", isPresented: $showingRenew) {
            TextField("New price (optional)", text: $newPriceText)
                .keyboardType(.decimalPad)
            Button("Renew") { renew() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(renewMessage)
        }
        .confirmationDialog("Delete this task?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.delete(taskID)
                dismiss()
            }
        } message: {
            Text("Its reminders will be cancelled. This can't be undone.")
        }
    }

    private var renewMessage: String {
        guard let task = store.task(withID: taskID) else { return "" }
        if task.repeatCycle == .never {
            return "This one-off task will be marked done. Enter what you paid to keep track of prices."
        }
        let next = store.schedule.dueDate(for: task, cycleOffset: 1)?.cardFormat ?? ""
        return "Next due \(next). Enter what you paid this time to compare next year."
    }

    private func renew() {
        let price = PriceFormat.parse(newPriceText)
        newPriceText = ""
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            store.renew(taskID, newPrice: price)
        }
        celebration += 1
    }

    @ViewBuilder
    private func actions(for task: RenewalTask) -> some View {
        VStack(spacing: 12) {
            if task.isCompleted {
                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { store.reopen(task.id) }
                } label: {
                    Label("Mark not done", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(PixelButtonStyle(fill: CardTint.yellow.strong))
            } else {
                Button {
                    newPriceText = ""
                    showingRenew = true
                } label: {
                    Label(task.repeatCycle == .never ? "Mark done" : "Mark renewed", systemImage: "checkmark.seal.fill")
                }
                .buttonStyle(PixelButtonStyle(fill: CardTint.green.strong))
            }

            Button {
                confirmingDelete = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(PixelButtonStyle(fill: Theme.paper, foreground: CardTint.pink.strong))
        }
        .padding(.top, 4)
    }
}

// MARK: - Cards

private struct HeroCard: View {
    @Environment(TaskStore.self) var store
    let task: RenewalTask

    var body: some View {
        let days = store.schedule.daysUntilDue(task, now: Date())

        HStack(spacing: 14) {
            Image(systemName: task.iconName)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(task.tint.strong))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.ink, lineWidth: 2))
                .symbolEffect(.bounce, value: task.cyclesCompleted)

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title.uppercased())
                    .font(.pixel(.title3, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if task.isCompleted {
                    Text("COMPLETED ✓")
                        .font(.pixel(.caption, weight: .black))
                        .foregroundStyle(CardTint.green.strong)
                } else {
                    CountdownBadge(days: days)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(task.tint.soft))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).strokeBorder(task.tint.border, lineWidth: 2))
    }
}

private struct DueCard: View {
    @Environment(TaskStore.self) var store
    let task: RenewalTask

    var body: some View {
        let schedule = store.schedule
        let due = schedule.nextDueDate(for: task)
        let upcoming = task.repeatCycle == .never ? [] : Array(schedule.upcomingDueDates(for: task, count: 4).dropFirst())

        PixelCard(title: task.isCompleted ? "Was due" : "Next renewal", icon: "calendar", tint: .green) {
            VStack(alignment: .leading, spacing: 12) {
                Text(due.cardFormat.uppercased())
                    .font(.pixel(.title3, weight: .black))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())

                if !task.isCompleted {
                    SegmentBar(fraction: schedule.timeRemainingFraction(task, now: Date()))
                }

                Text(task.repeatSummary().uppercased())
                    .font(.pixel(.caption, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)

                if let weekday = task.preferredWeekday {
                    Callout(
                        text: "If the date isn't a \(weekday.fullLabel), the \(weekday.fullLabel) before is used.",
                        tint: .green,
                        icon: "arrow.uturn.backward.circle.fill"
                    )
                }

                if !upcoming.isEmpty && !task.isCompleted {
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "Coming up")
                        ForEach(upcoming, id: \.self) { date in
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(CardTint.yellow.strong)
                                Text(date.cardFormat)
                                    .font(.pixel(.footnote))
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct RemindersCard: View {
    @Environment(TaskStore.self) var store
    @Environment(NotificationManager.self) var notifications
    let task: RenewalTask

    var body: some View {
        let now = Date()
        let reminders = store.schedule.reminders(for: task, occurrences: 1)

        PixelCard(title: "Reminders", icon: "bell.fill", tint: .yellow) {
            VStack(alignment: .leading, spacing: 10) {
                if task.isCompleted {
                    Text("No reminders — this task is done.")
                        .font(.pixel(.footnote))
                        .foregroundStyle(Theme.inkSoft)
                } else if reminders.isEmpty {
                    Text("No reminders set. Tap Edit to add some.")
                        .font(.pixel(.footnote))
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    ForEach(reminders) { reminder in
                        let sent = reminder.fireDate <= now
                        HStack(spacing: 8) {
                            Image(systemName: sent ? "checkmark.circle.fill" : "bell.badge.fill")
                                .foregroundStyle(sent ? Theme.inkSoft : CardTint.yellow.strong)
                            Text(reminder.offset == .onTheDay ? "ON THE DAY" : "\(reminder.offset.chipLabel.uppercased()) BEFORE")
                                .font(.pixel(.caption, weight: .bold))
                            Spacer(minLength: 4)
                            Text(reminder.fireDate.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                                .font(.pixel(.caption))
                        }
                        .foregroundStyle(sent ? Theme.inkSoft : Theme.ink)
                        .strikethrough(sent)
                    }
                }

                if notifications.isDenied && !task.isCompleted {
                    Callout(text: "Notifications are off in Settings", tint: .pink, icon: "bell.slash.fill")
                }
            }
        }
    }
}

private struct ProviderCard: View {
    let provider: ProviderDetails
    let tint: CardTint

    var body: some View {
        PixelCard(title: "Current provider", icon: "building.2.fill", tint: .blue) {
            VStack(alignment: .leading, spacing: 10) {
                if !provider.name.isEmpty {
                    row(label: "Provider", value: provider.name)
                }
                if !provider.policyNumber.isEmpty {
                    row(label: "Policy / ref", value: provider.policyNumber)
                }
                HStack(spacing: 10) {
                    if let phoneURL {
                        Link(destination: phoneURL) {
                            Label("Call", systemImage: "phone.fill")
                        }
                        .buttonStyle(PixelButtonStyle(fill: CardTint.blue.strong))
                    }
                    if let websiteURL {
                        Link(destination: websiteURL) {
                            Label("Website", systemImage: "safari.fill")
                        }
                        .buttonStyle(PixelButtonStyle(fill: CardTint.purple.strong))
                    }
                }
                if !provider.phone.isEmpty {
                    row(label: "Phone", value: provider.phone)
                }
            }
        }
    }

    private var phoneURL: URL? {
        let digits = provider.phone.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
    }

    private var websiteURL: URL? {
        let trimmed = provider.website.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed.contains("://") ? trimmed : "https://\(trimmed)")
    }

    private func row(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            FieldLabel(text: label)
            Text(value)
                .font(.pixel(.body, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .textSelection(.enabled)
        }
    }
}

private struct PriceCard: View {
    let task: RenewalTask

    var body: some View {
        PixelCard(title: "Price", icon: "banknote.fill", tint: .pink) {
            VStack(alignment: .leading, spacing: 10) {
                if let last = task.lastPrice {
                    HStack(alignment: .firstTextBaseline) {
                        FieldLabel(text: "Last paid")
                        Spacer()
                        Text(PriceFormat.display(last))
                            .font(.system(size: 26, weight: .black, design: .monospaced))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                    }
                }
                if let last = task.lastPrice, let previous = task.previousPrice {
                    let change = last - previous
                    let rising = change > 0
                    HStack(spacing: 6) {
                        Image(systemName: rising ? "arrow.up.right" : "arrow.down.right")
                        Text("\(rising ? "UP" : "DOWN") \(PriceFormat.display(abs(change))) FROM \(PriceFormat.display(previous))")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .font(.pixel(.caption, weight: .bold))
                    .foregroundStyle(rising ? CardTint.pink.strong : CardTint.green.strong)
                    if rising {
                        Callout(text: "Price went up — worth shopping around!", tint: .yellow, icon: "magnifyingglass")
                    }
                }
            }
        }
    }
}
