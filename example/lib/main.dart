import 'dart:async';

import 'package:devreply/devreply.dart';
import 'package:flutter/material.dart';

// Your app's public keys from the DevReply dashboard (Settings → Platforms). Safe to ship.
// flutter run --dart-define=DEVREPLY_IOS_KEY=pk_… --dart-define=DEVREPLY_ANDROID_KEY=pk_…
const iosKey = String.fromEnvironment('DEVREPLY_IOS_KEY', defaultValue: 'pk_YOUR_IOS_KEY');
const androidKey = String.fromEnvironment('DEVREPLY_ANDROID_KEY', defaultValue: 'pk_YOUR_ANDROID_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DemoApp());
  await DevReply.configure(ios: iosKey, android: androidKey);
  await DevReply.setAttributes({'demo_app': true, 'framework': 'flutter'});
}

const ink = Color(0xFF111111);
const lemon = Color(0xFFF6EB37);
const pink = Color(0xFFFF5FA2);

/// A blank app with one button. It opens DevReply's native chat (SwiftUI on iOS, Compose on Android).
class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(debugShowCheckedModeBanner: false, home: Home());
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int unread = 0;
  StreamSubscription<int>? sub;

  @override
  void initState() {
    super.initState();
    sub = DevReply.unreadCountChanges.listen((n) => setState(() => unread = n));
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lemon,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: ink,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: const Text('DEMO APP · FLUTTER',
                    style: TextStyle(color: lemon, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1.2)),
              ),
              const SizedBox(height: 20),
              const Text('Talk to the developer.',
                  style: TextStyle(color: ink, fontSize: 44, fontWeight: FontWeight.w900, height: 1.1)),
              const SizedBox(height: 20),
              const Text('This is a Flutter app with one button. It opens DevReply\'s native chat.',
                  style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 20),
              Text('Unread: $unread', style: const TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w500)),
              const Spacer(),
              _button('Message the developer', pink, () => DevReply.present()),
              const SizedBox(height: 16),
              _button('Report a bug', Colors.white, () => DevReply.present(DevReplyCategory.bug)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(String label, Color fill, VoidCallback onTap) => Material(
        color: fill,
        shape: const Border.fromBorderSide(BorderSide(color: ink, width: 3)),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 62,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(label, style: const TextStyle(color: ink, fontSize: 19, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
      );
}
