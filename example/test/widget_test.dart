import 'package:devreply_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the demo shows its button', (tester) async {
    await tester.pumpWidget(const DemoApp());
    expect(find.text('Message the developer'), findsOneWidget);
  });
}
