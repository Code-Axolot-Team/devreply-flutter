import 'package:devreply/devreply.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('devreply'),
      (call) async {
        calls.add(call);
        return call.method == 'unreadCount' ? 3 : null;
      },
    );
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('configure passes this platform\'s key only', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await DevReply.configure(ios: 'pk_ios', android: 'pk_android');
    expect(calls.single.method, 'configure');
    expect(calls.single.arguments, {'key': 'pk_android'});
  });

  test('configure ignores a missing or secret key', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await DevReply.configure(android: 'pk_android');
    await DevReply.configure(ios: 'sk_secret');
    expect(calls, isEmpty);
  });

  test('present, user, attributes, unread', () async {
    await DevReply.present(DevReplyCategory.bug);
    await DevReply.setUser(name: 'Ana');
    await DevReply.setAttributes({'plan': 'pro', 'decks': 12, 'trial': false, 'old': null});
    expect(await DevReply.unreadCount, 3);
    expect(calls.map((c) => c.method), ['present', 'setUser', 'setAttributes', 'unreadCount']);
    expect(calls[0].arguments, {'category': 'bug'});
    expect(() => DevReply.setAttributes({'bad': DateTime(2026)}), throwsArgumentError);
  });
}
