// Copies the iOS SDK sources (../swift/Sources/DevReply) into ios/devreply/Sources/devreply/DevReplySDK, where
// both the pod and the Swift package compile them
// with the app. Run it in the DevReply repo after changing the iOS SDK, and before publishing:
//   dart run tool/sync_ios_sdk.dart
// The published package carries the copy.
import 'dart:io';

void main() {
  final from = Directory('../swift/Sources/DevReply');
  final to = Directory('ios/devreply/Sources/devreply/DevReplySDK');
  if (!from.existsSync()) {
    if (!to.existsSync()) throw StateError('ios/devreply/Sources/devreply/DevReplySDK is missing');
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
  stdout.writeln('ios/devreply/Sources/devreply/DevReplySDK ← sdk/swift/Sources/DevReply');
}
