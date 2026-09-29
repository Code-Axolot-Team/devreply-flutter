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

  /// iOS: the APNs device token as hex (e.g. from firebase_messaging `getAPNSToken()`). DevReply never
  /// asks for permission before the user writes; the chat offers it. Android push comes later.
  static Future<void> registerPushToken(String hexToken) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    await _channel.invokeMethod<void>('registerPushToken', {'token': hexToken});
  }
}
