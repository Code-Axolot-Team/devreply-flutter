## 0.4.4

* `DevReply.present(category, DevReplyPresentOptions(message: …, attributes: {…}))`: prefills the new
  conversation's message and attaches context the team sees on that conversation. Returns false when the
  chat is switched off.
* `DevReply.isAvailable`: false when the team switched the chat off in the dashboard.
* `DevReply.events`: messengerOpened, messengerClosed, conversationStarted, messageSent.
* `DevReply.setLightTheme(DevReplyColors(...))` and `DevReply.setDarkTheme(...)`: the chat's six colours.
  Dark mode is off by default; `DevReplyColors.devReplyDark` is DevReply's deep-blue theme, `null` turns it
  off. DevReply derives the rest and keeps its own line widths and icons.
* `deleteUser()` never gives up: if DevReply can't be reached, the device forgets the user now and the
  deletion is retried at the next launches (false = queued).

## 0.4.3

* Signed-in users: `DevReply.login(userId)` after sign-in (your own id for the user; the team sees it, your
  backend can delete the user by it), `DevReply.logout()` on every sign-out (the device forgets the chat; the
  next person starts empty), `DevReply.deleteUser()` in your delete-account flow (deletes the user's data, then
  logs out; `false` if DevReply couldn't be reached).
* Notification taps from firebase_messaging: `DevReply.handleNotificationOpened(message.data)` from
  `onMessageOpenedApp` and `getInitialMessage()` opens the conversation (`false` for your own). DevReply never
  takes over your notification handling.
* iOS: a reinstall starts clean (the Keychain outlives the app).

## 0.4.2

* Push notifications on Android, like Intercom: your app keeps its Firebase Cloud Messaging setup and passes
  DevReply the FCM token (`DevReply.registerPushToken(token)`) and DevReply's messages
  (`DevReply.handlePush(message.data)` from `onMessage` and `onBackgroundMessage`). The chat offers to turn
  notifications on after the user's first message; a tap opens the conversation.

## 0.4.0

* Replies show who wrote them: the teammate's name, title and photo, once per group of replies.
* The app's icon in the chat's header; the team's faces on the chat's home screen.
* Links from DevReply's emails ("Reply in the app") open the right conversation: the plugin catches
  `yourapp://devreply?devreply=<id>` by itself; `DevReply.handle(url)` for apps that route links themselves.
* A refused public key isn't retried in a loop.
* The chat speaks the user's language (15 languages, the device's by default); `DevReply.setLocale('es')` to choose.

## 0.3.2

* First release: opens the native DevReply chat (SwiftUI on iOS, Jetpack Compose on Android) from Dart.
  `configure`, `present`, `setUser`, `setAttributes`, `unreadCount` and `unreadCountChanges`,
  `setShowsUnreadBubble`, `registerPushToken` (iOS).
