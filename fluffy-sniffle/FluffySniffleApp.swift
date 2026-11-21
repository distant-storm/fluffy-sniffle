import SwiftUI
import UserNotifications

@main
struct FluffySniffleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = TaskStore()
    @State private var notifications = NotificationManager()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                .environment(notifications)
                .environment(appDelegate.router)
                .tint(Theme.headline)
                .preferredColorScheme(.light)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    let router = AppRouter()
    private lazy var notificationDelegate = NotificationDelegate(router: router)

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Must be set before launch finishes so taps that open the app are delivered.
        UNUserNotificationCenter.current().delegate = notificationDelegate
        return true
    }
}
