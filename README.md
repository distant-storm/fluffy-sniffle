# fluffy-sniffle

A minimal native iPhone app built with SwiftUI.

## Build and install from Windows (Codemagic + TestFlight)

`codemagic.yaml` builds the app on a cloud Mac, signs it, and uploads it to App Store Connect. Install it on your iPhone with TestFlight. Builds are marked TestFlight internal-only, so they can't be sent to external testers or the App Store.

The bundle identifier is `com.distantstorm.fluffy-sniffle`. If you change it, update both `codemagic.yaml` and `fluffy-sniffle.xcodeproj/project.pbxproj`.

## Build on a Mac (optional)

1. Open `fluffy-sniffle.xcodeproj` in Xcode.
2. In **Signing & Capabilities**, select your Apple developer **Team**.
3. Connect and unlock your iPhone, select it as the run destination, then click **Run**.
