import SwiftUI

struct HomeView: View {
    @Environment(TaskStore.self) var store
    @Environment(NotificationManager.self) var notifications
    @Environment(AppRouter.self) var router
    @Environment(\.scenePhase) var scenePhase

    @State var path: [UUID] = []
    @State var showingNewTask = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        HeaderBanner()

                        if notifications.isDenied {
                            NotificationsOffCard()
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        if let error = store.loadError {
                            Callout(text: error, tint: .pink, icon: "exclamationmark.triangle.fill")
                        }

                        if store.tasks.isEmpty {
                            EmptyStateCard { showingNewTask = true }
                                .transition(.scale(scale: 0.9).combined(with: .opacity))
                        } else {
                            SummaryCard()
                            taskSection("Overdue", icon: "exclamationmark.circle.fill", tint: .pink, tasks: overdueTasks)
                            taskSection("Upcoming", icon: "calendar", tint: .purple, tasks: upcomingTasks)
                            taskSection("Done", icon: "checkmark.seal.fill", tint: .green, tasks: store.completedTasks)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 120)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: store.tasks)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: notifications.isDenied)
                }
                .scrollIndicators(.hidden)

                newTaskButton
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                TaskDetailView(taskID: id)
            }
            .sheet(isPresented: $showingNewTask) {
                TaskEditorView(existing: nil)
            }
        }
        .task {
            await notifications.refreshStatus()
            await notifications.reschedule(tasks: store.tasks, schedule: store.schedule)
        }
        .onChange(of: store.tasks) { _, tasks in
            Task { await notifications.reschedule(tasks: tasks, schedule: store.schedule) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await notifications.refreshStatus()
                await notifications.reschedule(tasks: store.tasks, schedule: store.schedule)
            }
        }
        .onChange(of: router.openTaskID, initial: true) { _, id in
            guard let id else { return }
            router.openTaskID = nil
            guard store.task(withID: id) != nil else { return }
            showingNewTask = false
            path = [id]
        }
    }

    private var overdueTasks: [RenewalTask] {
        store.activeTasks.filter { store.schedule.daysUntilDue($0, now: Date()) < 0 }
    }

    private var upcomingTasks: [RenewalTask] {
        store.activeTasks.filter { store.schedule.daysUntilDue($0, now: Date()) >= 0 }
    }

    private var newTaskButton: some View {
        Button {
            showingNewTask = true
        } label: {
            Label("New task", systemImage: "plus")
        }
        .buttonStyle(PixelButtonStyle(fill: CardTint.purple.strong))
        .padding(.horizontal, 32)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [Theme.background.opacity(0), Theme.background],
                startPoint: .top, endPoint: .center
            )
            .padding(.top, -30)
            .ignoresSafeArea()
        )
    }

    @ViewBuilder
    private func taskSection(_ title: String, icon: String, tint: CardTint, tasks: [RenewalTask]) -> some View {
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .foregroundStyle(tint.strong)
                    Text("\(title.uppercased()) · \(tasks.count)")
                        .font(.pixel(.footnote, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                }
                .padding(.leading, 4)

                ForEach(tasks) { task in
                    NavigationLink(value: task.id) {
                        TaskCardView(task: task)
                    }
                    .buttonStyle(SquishStyle())
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal: .scale(scale: 0.85).combined(with: .opacity)
                    ))
                }
            }
        }
    }
}

// MARK: - Header

private struct HeaderBanner: View {
    @State var appeared = false

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: "sparkle")
                    .foregroundStyle(CardTint.yellow.strong)
                    .symbolEffect(.pulse, options: .repeating)
                Spacer()
                Image(systemName: "crown.fill")
                    .foregroundStyle(CardTint.yellow.strong)
                    .rotationEffect(.degrees(appeared ? 0 : -20))
                Spacer()
                Image(systemName: "sparkle")
                    .foregroundStyle(CardTint.yellow.strong)
                    .symbolEffect(.pulse, options: .repeating)
            }
            .font(.system(size: 18, weight: .bold))
            .padding(.horizontal, 30)

            Text("RENEWAL")
                .font(.system(size: 46, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("QUESTS")
                .font(.system(size: 46, weight: .black, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(colors: [Theme.headline, Theme.headlineDeep], startPoint: .top, endPoint: .bottom)
                )
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text("NEVER MISS A RENEWAL")
                Image(systemName: "heart.fill")
                    .foregroundStyle(CardTint.pink.strong)
            }
            .font(.pixel(.caption, weight: .bold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.paper))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.ink, lineWidth: 2))
            .padding(.top, 6)
        }
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { appeared = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Summary

private struct SummaryCard: View {
    @Environment(TaskStore.self) var store

    var body: some View {
        let now = Date()
        let days = store.activeTasks.map { store.schedule.daysUntilDue($0, now: now) }
        let overdue = days.filter { $0 < 0 }.count
        let soon = days.filter { (0...30).contains($0) }.count

        PixelCard(title: "Today's summary", icon: "chart.bar.fill", tint: .blue) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    StatTile(value: overdue, label: "Overdue", tint: .pink)
                    StatTile(value: soon, label: "Next 30d", tint: .yellow)
                    StatTile(value: store.activeTasks.count, label: "Active", tint: .green)
                }
                if let next = store.activeTasks.first {
                    let daysLeft = store.schedule.daysUntilDue(next, now: now)
                    Callout(
                        text: "Next up: \(next.title) · \(CountdownText.phrase(for: daysLeft))",
                        tint: daysLeft < 0 ? .pink : .purple,
                        icon: next.iconName
                    )
                }
            }
        }
    }
}

private struct StatTile: View {
    let value: Int
    let label: String
    let tint: CardTint

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 26, weight: .black, design: .monospaced))
                .foregroundStyle(value > 0 ? tint.strong : Theme.inkSoft)
                .contentTransition(.numericText(value: Double(value)))
            Text(label.uppercased())
                .font(.pixel(.caption2, weight: .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint.soft))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(tint.border, lineWidth: 1.5))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: value)
    }
}

// MARK: - Empty & permission states

private struct EmptyStateCard: View {
    let action: () -> Void
    @State var bounce = 0

    var body: some View {
        PixelCard(title: "Start your first quest", icon: "flag.fill", tint: .purple) {
            VStack(spacing: 14) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(CardTint.purple.strong)
                    .symbolEffect(.bounce, value: bounce)
                    .onAppear { bounce += 1 }
                Text("Add things you must renew — home insurance, car tax, broadband — and get reminded before they're due.")
                    .font(.pixel(.footnote))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Button("Add a renewal", action: action)
                    .buttonStyle(PixelButtonStyle(fill: CardTint.green.strong))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct NotificationsOffCard: View {
    @Environment(\.openURL) var openURL

    var body: some View {
        PixelCard(title: "Notifications are off", icon: "bell.slash.fill", tint: .pink) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Turn on notifications so reminders can reach you.")
                    .font(.pixel(.footnote))
                    .foregroundStyle(Theme.ink)
                Button("Open settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(PixelButtonStyle(fill: CardTint.pink.strong))
            }
        }
    }
}
