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

**Languages:** the chat follows the device's language (15 languages); `DevReply.setLocale('es')` if your app has its
own language setting (`null` follows the device).

**Who replied:** each reply shows the teammate's name, title and photo (their persona in the dashboard), and the
chat's header shows your app icon. Nothing to set up in the app.

**Replies from email:** DevReply emails users replies they haven't read, with a "Reply in the app" button that opens
`yourapp://devreply?devreply=<conversation>`. Add the scheme (iOS `CFBundleURLTypes` in `Info.plist`; Android a `VIEW`
intent filter with `android:scheme="yourapp" android:host="devreply"` on `MainActivity`) and set `yourapp://devreply`
as the deep link in the dashboard (the app → Settings). The plugin catches these links itself; if a links package
swallows them first, pass them on with `DevReply.handle(url)`. With go_router and Flutter deep linking on, redirect
`/devreply` to where the user already is.

**Push notifications**, like Intercom: your app keeps its firebase_messaging setup and passes DevReply the token
and, on Android, DevReply's messages:

```dart
final token = Platform.isIOS
    ? await FirebaseMessaging.instance.getAPNSToken()   // iOS: the APNs token
    : await FirebaseMessaging.instance.getToken();      // Android: the FCM token
if (token != null) await DevReply.registerPushToken(token);
FirebaseMessaging.instance.onTokenRefresh.listen((t) { if (Platform.isAndroid) DevReply.registerPushToken(t); });

// Android: DevReply shows its own notification; a tap opens the conversation.
FirebaseMessaging.onMessage.listen((m) async { if (await DevReply.handlePush(m.data)) return; /* yours */ });
// and first thing in your onBackgroundMessage handler:
//   if (await DevReply.handlePush(message.data)) return;

// Taps (iOS, and Android notifications firebase_messaging shows), including the one that launched the app.
FirebaseMessaging.onMessageOpenedApp.listen((m) async { if (await DevReply.handleNotificationOpened(m.data)) return; /* yours */ });
final initial = await FirebaseMessaging.instance.getInitialMessage();
if (initial != null) await DevReply.handleNotificationOpened(initial.data);
```

DevReply never takes over your notification handling; `handleNotificationOpened` returns false for your own
notifications. The dashboard's push card shows "✓ Taps open the chat" once a tap opened a conversation.

Upload your push keys in the dashboard (the APNs key; the Firebase service account for Android). The chat asks
for the notification permission only after the user's first message.

## Sign-in, sign-out and account deletion

If your app has accounts:

```dart
await DevReply.login(user.id);               // after sign-in: your own id for the user, never an email or a secret
await DevReply.logout();                     // on every sign-out and account switch
final ok = await DevReply.deleteUser();      // in your delete-account flow; false if DevReply couldn't be reached
```

- `login` labels the user for your team (the dashboard shows it as "User ID (your app)") and lets your backend
  delete them by it. It doesn't merge chats across devices: the id isn't verified, so it never gives one device
  another's conversations. If another id was signed in on this device, DevReply logs out first.
- `logout` revokes this install and its push token; the device forgets the chat and the next person starts empty.
  The conversations stay with your team.
- `deleteUser` deletes the user's name, email, attributes, conversations, messages and files, then logs out.
  Apple requires account deletion in the app.

Your backend can delete a user too, with a read-and-write secret key (never in an app):

```sh
curl -X DELETE "https://api.devreply.com/v1/project/users?user_id=<your id>" \
  -H "Authorization: Bearer $DEVREPLY_SECRET_KEY"
# {"deleted": 1}: every DevReply user with that id, on every device. ?id=<DevReply's user id> for one user.
```

Your team can also delete a user in the dashboard (the inbox's user panel → Delete user).

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
