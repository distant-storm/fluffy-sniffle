# fluffy-sniffle

An iPhone app (SwiftUI, iOS 17+) for remembering renewals such as home insurance.

- Add a task with a date, current provider details, and last year's price.
- Repeat it weekly, monthly, or yearly. Optionally pick a **nearest day**: if the date lands on another weekday, the same weekday *before* it is used (e.g. a Sunday renewal with "Wed" picked moves to the Wednesday before).
- Choose several reminders (on the day, 1–3 days, 1–2 weeks, 1–2 months before) and a time. Reminders are local notifications scheduled on the phone, so no server is needed.
- Mark a task renewed to move to the next cycle and record the new price.

## Project layout

- `fluffy-sniffle/Core` — task model and date/reminder logic (Foundation only).
- `fluffy-sniffle/App` — storage (JSON in the app's Documents folder) and notification scheduling.
- `fluffy-sniffle/Theme`, `fluffy-sniffle/Views` — the UI.
- `Tests/RenewalCoreTests` — tests for `Core`. Run with `swift test` on macOS or Linux.

## Build and install from Windows (Codemagic + TestFlight)

`codemagic.yaml` builds the app on a cloud Mac, signs it, and uploads it to App Store Connect. Install it on your iPhone with TestFlight. Builds are marked TestFlight internal-only, so they can't be sent to external testers or the App Store.

The bundle identifier is `com.distantstorm.fluffy-sniffle`. If you change it, update both `codemagic.yaml` and `fluffy-sniffle.xcodeproj/project.pbxproj`.

## Build on a Mac (optional)

1. Open `fluffy-sniffle.xcodeproj` in Xcode.
2. In **Signing & Capabilities**, select your Apple developer **Team**.
3. Connect and unlock your iPhone, select it as the run destination, then click **Run**.
