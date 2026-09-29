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
