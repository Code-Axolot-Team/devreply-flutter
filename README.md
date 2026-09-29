# DevReply for Flutter

The in-app chat between your app's users and you, answered from the [DevReply dashboard](https://app.devreply.com).
This plugin opens the **native** DevReply chat (SwiftUI on iOS, Jetpack Compose on Android) from Dart. No UI in
Dart, no web view.

- Home with start buttons (bug, billing, idea, question), the user's conversations, and the chat.
- Photos and files, name first, optional email, "we got it" with your reply time.
- An unread bubble over your app, and the unread count as a Dart stream.

Requires iOS 17 and Android 8 (API 26).

## Install

```sh
flutter pub add devreply
```

- **iOS:** in `ios/Podfile`, `platform :ios, '17.0'`.
- **Android:** in `android/app/build.gradle(.kts)`, `minSdk = 26`. The plugin adds JitPack (where the DevReply
  Android SDK is published) to the build's repositories; if your `settings.gradle` forbids project repositories,
  add `maven { url = uri("https://jitpack.io") }` there.

Using a coding agent? Give it your app's setup guide from the dashboard (Settings → Add DevReply to your app):
it has your keys and does these steps for you.

## Use

```dart
import 'package:devreply/devreply.dart';

// Once, at startup: your public keys from the dashboard (safe to ship). Never a secret key (sk_…).
await DevReply.configure(ios: 'pk_…', android: 'pk_…');

// From any button
DevReply.present();                          // or DevReply.present(DevReplyCategory.bug)

// Optional
DevReply.setUser(name: 'Ana', email: 'ana@example.com');
DevReply.setAttributes({'plan': 'pro', 'trial': false});
DevReply.unreadCountChanges.listen((count) => setState(() => unread = count));
DevReply.setShowsUnreadBubble(false);        // if you show the count yourself
```

**Push (iOS):** pass the APNs device token as hex (e.g. firebase_messaging `getAPNSToken()`) with
`DevReply.registerPushToken(token)`, and upload your APNs key in the dashboard. Android push comes later.

## How it's built

`ios/` compiles the DevReply iOS SDK sources (`ios/DevReplySDK`, the same code as
[devreply-ios](https://github.com/Code-Axolot-Team/devreply-ios)) with a thin plugin class. `android/` depends on
[devreply-android](https://github.com/Code-Axolot-Team/devreply-android) from JitPack. Dart only passes calls through.

## Example and tests

```sh
flutter test
cd example && flutter run --dart-define=DEVREPLY_IOS_KEY=pk_… --dart-define=DEVREPLY_ANDROID_KEY=pk_…
maestro test -e NONCE=123 maestro/chat.yaml   # with a script replying "Founder reply 123" from the dashboard API
```

## License

MIT, see [LICENSE](LICENSE). Issues and ideas welcome: see [CONTRIBUTING](CONTRIBUTING.md).
