// Copies the iOS SDK sources (../swift/Sources/DevReply) into ios/DevReplySDK, so the pod compiles them
// with the app. Run it in the DevReply repo after changing the iOS SDK, and before publishing:
//   dart run tool/sync_ios_sdk.dart
// The published package carries the copy.
import 'dart:io';

void main() {
  final from = Directory('../swift/Sources/DevReply');
  final to = Directory('ios/DevReplySDK');
  if (!from.existsSync()) {
    if (!to.existsSync()) throw StateError('ios/DevReplySDK is missing');
    return;
  }
  if (to.existsSync()) to.deleteSync(recursive: true);
  for (final entity in from.listSync(recursive: true)) {
    final target = entity.path.replaceFirst(from.path, to.path);
    if (entity is Directory) {
      Directory(target).createSync(recursive: true);
    } else if (entity is File) {
      File(target).parent.createSync(recursive: true);
      entity.copySync(target);
    }
  }
  stdout.writeln('ios/DevReplySDK ← sdk/swift/Sources/DevReply');
}
