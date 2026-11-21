import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class NotificationManager {
    private(set) var authorization: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    var isDenied: Bool { authorization == .denied }

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        authorization = settings.authorizationStatus
    }

    func requestPermissionIfNeeded() async {
        await refreshStatus()
        guard authorization == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await refreshStatus()
    }

    /// Replaces pending reminders with the soonest planned ones (iOS allows 64 per app).
    func reschedule(tasks: [RenewalTask], schedule: RenewalSchedule) async {
        let plan = schedule.plan(tasks: tasks, after: Date())
        let planned = Set(plan.map(\.id))
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        let stale = pending.filter { !planned.contains($0) }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        let tasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        for reminder in plan {
            guard let task = tasksByID[reminder.taskID] else { continue }
            let content = UNMutableNotificationContent()
            content.title = task.title
            content.body = Self.body(for: task, reminder: reminder)
            content.sound = .default
            content.userInfo = ["taskID": task.id.uuidString]

            let components = schedule.calendar.dateComponents(
                [.year, .month, .day, .hour, .minute], from: reminder.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            // Re-adding an existing identifier replaces it, so edits update the text and time.
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }

    private static func body(for task: RenewalTask, reminder: PlannedReminder) -> String {
        var parts = ["\(reminder.offset.dueText) (\(reminder.dueDate.shortCardFormat))."]
        var details: [String] = []
        let provider = task.provider.name.trimmingCharacters(in: .whitespaces)
        if !provider.isEmpty { details.append(provider) }
        if let price = task.lastPrice { details.append("last price \(PriceFormat.display(price))") }
        if !details.isEmpty { parts.append(details.joined(separator: " · ")) }
        return parts.joined(separator: " ")
    }
}

/// Lets a tapped notification open its task.
@MainActor
@Observable
final class AppRouter {
    var openTaskID: UUID?
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let router: AppRouter

    init(router: AppRouter) {
        self.router = router
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let idString = response.notification.request.content.userInfo["taskID"] as? String
        if let idString, let id = UUID(uuidString: idString) {
            let router = router
            Task { @MainActor in
                router.openTaskID = id
            }
        }
        completionHandler()
    }
}
