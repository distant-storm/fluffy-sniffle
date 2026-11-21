import SwiftUI

struct TaskEditorView: View {
    @Environment(TaskStore.self) var store
    @Environment(NotificationManager.self) var notifications
    @Environment(\.dismiss) var dismiss

    @State var draft: RenewalTask
    @State var dueDate: Date
    @State var reminderTime: Date
    @State var priceText: String
    @State var saveTapped = 0

    private let isNew: Bool
    private let original: RenewalTask
    private let originalDueDate: Date

    static let iconChoices = [
        "house.fill", "car.fill", "heart.fill", "bolt.fill", "flame.fill", "drop.fill",
        "wifi", "phone.fill", "tv.fill", "creditcard.fill", "doc.text.fill", "pawprint.fill",
        "airplane", "cross.case.fill", "key.fill", "star.fill",
    ]

    init(existing: RenewalTask?) {
        let calendar = Calendar.autoupdatingCurrent
        let task = existing ?? RenewalTask(
            title: "",
            anchorDate: calendar.date(byAdding: .month, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        )
        let due = RenewalSchedule(calendar: calendar).nominalDate(for: task) ?? task.anchorDate
        isNew = existing == nil
        original = task
        originalDueDate = due
        _draft = State(initialValue: task)
        _dueDate = State(initialValue: due)
        _reminderTime = State(initialValue: calendar.date(
            bySettingHour: task.reminderHour, minute: task.reminderMinute, second: 0, of: Date()
        ) ?? Date())
        _priceText = State(initialValue: task.lastPrice.map(PriceFormat.editable) ?? "")
    }

    private var trimmedTitle: String {
        draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        taskCard
                        dateCard
                        remindersCard
                        providerCard
                        priceCard
                        notesCard
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
            }
            .navigationTitle(isNew ? "New task" : "Edit task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .sensoryFeedback(.success, trigger: saveTapped)
        }
        .tint(Theme.headline)
    }

    // MARK: - Sections

    private var taskCard: some View {
        PixelCard(title: "Task", icon: "flag.fill", tint: .purple) {
            VStack(alignment: .leading, spacing: 14) {
                PixelTextField(label: "What needs renewing?", prompt: "e.g. Home insurance", text: $draft.title)

                FieldLabel(text: "Icon")
                FlowLayout(spacing: 8) {
                    ForEach(Self.iconChoices, id: \.self) { icon in
                        iconButton(icon)
                    }
                }

                FieldLabel(text: "Colour")
                HStack(spacing: 10) {
                    ForEach(CardTint.allCases) { tint in
                        colorButton(tint)
                    }
                }
            }
        }
    }

    private func iconButton(_ icon: String) -> some View {
        let selected = draft.iconName == icon
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return Button {
            draft.iconName = icon
        } label: {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(selected ? Color.white : draft.tint.strong)
                .frame(width: 40, height: 40)
                .background(shape.fill(selected ? draft.tint.strong : Theme.field))
                .overlay(shape.strokeBorder(selected ? Theme.ink : draft.tint.border, lineWidth: selected ? 2 : 1.5))
                .scaleEffect(selected ? 1.08 : 1)
                .symbolEffect(.bounce, value: selected)
        }
        .buttonStyle(SquishStyle(scale: 0.85))
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: selected)
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityLabel(icon.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " "))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func colorButton(_ tint: CardTint) -> some View {
        let selected = draft.tint == tint
        return Button {
            draft.tint = tint
        } label: {
            Circle()
                .fill(tint.strong)
                .frame(width: 34, height: 34)
                .overlay(Circle().strokeBorder(Theme.ink, lineWidth: selected ? 3 : 0))
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white)
                        .opacity(selected ? 1 : 0)
                )
                .scaleEffect(selected ? 1.15 : 1)
        }
        .buttonStyle(SquishStyle(scale: 0.85))
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: selected)
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityLabel(tint.rawValue)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var dateCard: some View {
        PixelCard(title: "Date & repeat", icon: "calendar", tint: .green) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    FieldLabel(text: "Renewal date")
                    Spacer()
                    DatePicker("Renewal date", selection: $dueDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(CardTint.green.strong)
                }

                FieldLabel(text: "Repeat")
                FlowLayout(spacing: 8) {
                    ForEach(RepeatCycle.allCases) { cycle in
                        ChipButton(label: cycle.label, isOn: draft.repeatCycle == cycle, tint: .green) {
                            draft.repeatCycle = cycle
                        }
                    }
                }

                FieldLabel(text: "Nearest day")
                FlowLayout(spacing: 8) {
                    ChipButton(label: "Any", isOn: draft.preferredWeekday == nil, tint: .green) {
                        draft.preferredWeekday = nil
                    }
                    ForEach(Weekday.mondayFirst) { day in
                        ChipButton(label: day.shortLabel, isOn: draft.preferredWeekday == day, tint: .green) {
                            draft.preferredWeekday = day
                        }
                    }
                }
                if let weekday = draft.preferredWeekday {
                    Text("If the date lands on another day, the \(weekday.fullLabel) before is used.")
                        .font(.pixel(.caption))
                        .foregroundStyle(Theme.inkSoft)
                        .transition(.opacity)
                }

                datePreview
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: draft.preferredWeekday)
        }
    }

    private var datePreview: some View {
        let preview = previewTask
        let schedule = store.schedule
        let count = preview.repeatCycle == .never ? 1 : 3

        return VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: count == 1 ? "Due" : "Next dates")
            ForEach(0..<count, id: \.self) { index in
                if let due = schedule.dueDate(for: preview, cycleOffset: index),
                   let nominal = schedule.nominalDate(for: preview, cycleOffset: index) {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(CardTint.yellow.strong)
                        Text(due.cardFormat)
                            .font(.pixel(.footnote, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                        if due != nominal {
                            Text("(was \(nominal.shortCardFormat))")
                                .font(.pixel(.caption2))
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(CardTint.green.soft))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(CardTint.green.border, lineWidth: 1.5))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: preview)
    }

    private var remindersCard: some View {
        PixelCard(title: "Reminders", icon: "bell.fill", tint: .yellow, trailing: "Before due") {
            VStack(alignment: .leading, spacing: 14) {
                FlowLayout(spacing: 8) {
                    ForEach(Array(ReminderOffset.allCases.reversed())) { offset in
                        ChipButton(label: offset.chipLabel, isOn: draft.reminderOffsets.contains(offset), tint: .yellow) {
                            if draft.reminderOffsets.contains(offset) {
                                draft.reminderOffsets.remove(offset)
                            } else {
                                draft.reminderOffsets.insert(offset)
                            }
                        }
                    }
                }
                HStack {
                    FieldLabel(text: "Remind me at")
                    Spacer()
                    DatePicker("Remind me at", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(CardTint.yellow.strong)
                }
                if notifications.isDenied {
                    Callout(text: "Notifications are off in Settings", tint: .pink, icon: "bell.slash.fill")
                }
            }
        }
    }

    private var providerCard: some View {
        PixelCard(title: "Current provider", icon: "building.2.fill", tint: .blue) {
            VStack(alignment: .leading, spacing: 12) {
                PixelTextField(label: "Provider", prompt: "e.g. Aviva", text: $draft.provider.name, capitalization: .words)
                PixelTextField(
                    label: "Policy / reference number", prompt: "Optional",
                    text: $draft.provider.policyNumber, capitalization: .characters
                )
                PixelTextField(label: "Phone", prompt: "Optional", text: $draft.provider.phone, keyboard: .phonePad)
                PixelTextField(
                    label: "Website", prompt: "Optional", text: $draft.provider.website,
                    keyboard: .URL, capitalization: .never
                )
            }
        }
    }

    private var priceCard: some View {
        PixelCard(title: "Price", icon: "banknote.fill", tint: .pink) {
            PixelTextField(
                label: "Last year's price", prompt: "0.00", text: $priceText,
                keyboard: .decimalPad, prefix: PriceFormat.currencySymbol
            )
        }
    }

    private var notesCard: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return PixelCard(title: "Notes", icon: "note.text", tint: .teal) {
            TextField("Anything else to remember", text: $draft.notes, axis: .vertical)
                .font(.pixel(.body))
                .foregroundStyle(Theme.ink)
                .lineLimit(3...8)
                .padding(10)
                .background(shape.fill(Theme.field))
                .overlay(shape.strokeBorder(Theme.ink.opacity(0.25), lineWidth: 1.5))
        }
    }

    // MARK: - Saving

    /// The draft with the edited date applied, for previews and saving.
    private var previewTask: RenewalTask {
        var task = draft
        let calendar = store.schedule.calendar
        let dateChanged = !calendar.isDate(dueDate, inSameDayAs: originalDueDate)
        // Counting cycles from the old anchor only makes sense if the date and cycle are unchanged.
        if isNew || dateChanged || task.repeatCycle != original.repeatCycle {
            task.anchorDate = calendar.startOfDay(for: dueDate)
            task.cyclesCompleted = 0
        }
        return task
    }

    private func save() {
        guard !trimmedTitle.isEmpty else { return }
        var task = previewTask
        task.title = trimmedTitle
        let time = store.schedule.calendar.dateComponents([.hour, .minute], from: reminderTime)
        task.reminderHour = time.hour ?? 9
        task.reminderMinute = time.minute ?? 0
        task.lastPrice = PriceFormat.parse(priceText)
        saveTapped += 1
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            store.upsert(task)
        }
        Task { await notifications.requestPermissionIfNeeded() }
        dismiss()
    }
}
