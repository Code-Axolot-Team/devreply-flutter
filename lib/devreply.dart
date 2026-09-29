/// DevReply for Flutter: passes calls through to the native iOS (SwiftUI) and Android (Jetpack
/// Compose) SDKs and opens their chat screen. No UI in Dart.
///
/// ```dart
/// await DevReply.configure(ios: 'pk_…', android: 'pk_…');   // once, at startup
/// DevReply.present();                                      // from any button
/// ```
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What a conversation is about. Set by the start button the user picked.
enum DevReplyCategory { bug, billing, idea, question, other }

/// The DevReply chat. All methods are static.
class DevReply {
  DevReply._();

  static const MethodChannel _channel = MethodChannel('devreply');
  static const EventChannel _unread = EventChannel('devreply/unread');

  /// Once, at startup, with the app's public keys from the DevReply dashboard (Settings → Platforms),
  /// one per platform. They're safe to ship. Never a secret key (`sk_…`).
  static Future<void> configure({String? ios, String? android}) async {
    final key = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => ios,
      TargetPlatform.android => android,
      _ => null,
    };
    if (key == null || !key.startsWith('pk_')) {
      debugPrint('DevReply: configure needs this platform\'s public key (pk_…) for $defaultTargetPlatform.');
      return;
    }
    await _channel.invokeMethod<void>('configure', {'key': key});
  }

  /// Opens the chat over the current screen. With a category, straight into a new conversation.
  static Future<void> present([DevReplyCategory? category]) =>
      _channel.invokeMethod<void>('present', {'category': category?.name});

  /// Who the user is, if the app knows. With a name set, the chat doesn't ask for one.
  static Future<void> setUser({String? name, String? email}) =>
      _channel.invokeMethod<void>('setUser', {'name': name, 'email': email});

  /// Custom attributes the team sees next to the user (plan, account id…): text, number or
  /// true/false. `null` removes one.
  static Future<void> setAttributes(Map<String, Object?> attributes) {
    for (final entry in attributes.entries) {
      final v = entry.value;
      if (v != null && v is! String && v is! num && v is! bool) {
        throw ArgumentError.value(v, entry.key, 'DevReply attributes are text, numbers or true/false');
      }
    }
    return _channel.invokeMethod<void>('setAttributes', {'attributes': attributes});
  }

  /// Unread replies from the team.
  static Future<int> get unreadCount async => await _channel.invokeMethod<int>('unreadCount') ?? 0;

  /// The unread count, now and whenever it changes.
  static Stream<int> get unreadCountChanges => _unread.receiveBroadcastStream().map((e) => e as int);

  /// While a reply is waiting, a small round DevReply button floats over the app and opens it.
  /// On by default; turn it off if the app shows [unreadCount] itself.
  static Future<void> setShowsUnreadBubble(bool shows) =>
      _channel.invokeMethod<void>('setShowsUnreadBubble', {'shows': shows});

  /// The chat's language: `es`, `pt-BR`, `ja`… (15 languages; others fall back to English), or null
  /// to follow the device. Takes effect at once, even with the chat open.
  static Future<void> setLocale(String? tag) => _channel.invokeMethod<void>('setLocale', {'tag': tag});

  /// Opens the conversation a DevReply link points to (`yourapp://devreply?devreply=<id>`, from the
  /// button in DevReply's emails). The plugin already catches these links when they open the app;
  /// call this only if a links package (app_links, go_router…) swallows them first. Returns false for
  /// any other URL.
  static Future<bool> handle(String url) async =>
      await _channel.invokeMethod<bool>('handle', {'url': url}) ?? false;

  /// After your user signs in: your own id for them (never an email or a secret). The team sees it next
  /// to the user, and your backend can delete the user by it. If someone else was signed in on this
  /// device, DevReply logs them out first, so nobody sees someone else's chats.
  static Future<void> login(String userId) => _channel.invokeMethod<void>('login', {'userId': userId});

  /// When your user signs out: DevReply forgets this device's chats; the next person starts empty.
  static Future<void> logout() => _channel.invokeMethod<void>('logout');

  /// When your user deletes their account: deletes their name, email, attributes, conversations,
  /// messages and files from DevReply, then logs out. False if DevReply couldn't be reached.
  static Future<bool> deleteUser() async => await _channel.invokeMethod<bool>('deleteUser') ?? false;

  /// The device's push token, so replies arrive as notifications. iOS: the APNs token as hex
  /// (firebase_messaging `getAPNSToken()`). Android: the FCM token (firebase_messaging `getToken()`,
  /// and `onTokenRefresh`). DevReply never asks for permission before the user writes; the chat offers it.
  static Future<void> registerPushToken(String token) async {
    if (defaultTargetPlatform != TargetPlatform.iOS && defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('registerPushToken', {'token': token});
  }

  /// Whether this push (firebase_messaging `RemoteMessage.data`) is one of DevReply's.
  static bool isDevReplyPush(Map<String, dynamic> data) => data['devreply_conversation_id'] is String;

  /// The user tapped a notification: pass its data (firebase_messaging `RemoteMessage.data` from
  /// `onMessageOpenedApp` and `getInitialMessage()`), and DevReply opens the conversation when it's one of
  /// DevReply's. Returns false for the app's own. Your push library owns notifications; DevReply only
  /// answers "is this mine?". On Android, DevReply's own notifications (from [handlePush]) open the
  /// conversation by themselves.
  static Future<bool> handleNotificationOpened(Map<String, dynamic> data) async {
    if (!isDevReplyPush(data)) return false;
    final strings = <String, String>{
      for (final e in data.entries)
        if (e.value is String) e.key: e.value as String,
    };
    return await _channel.invokeMethod<bool>('handleNotificationOpened', {'data': strings}) ?? false;
  }

  /// Android: shows DevReply's push (a reply from the team) as a notification; a tap opens that
  /// conversation. Call it from `FirebaseMessaging.onMessage` and your `onBackgroundMessage` handler.
  /// Returns false for any other message (handle those yourself), and on iOS, where DevReply shows its
  /// pushes itself.
  static Future<bool> handlePush(Map<String, dynamic> data) async {
    if (defaultTargetPlatform != TargetPlatform.android || !isDevReplyPush(data)) return false;
    final strings = data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    return await _channel.invokeMethod<bool>('handlePush', {'data': strings}) ?? false;
  }
}
