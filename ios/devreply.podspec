# The DevReply iOS SDK (SwiftUI) compiled into this pod from DevReplySDK/ (copied from the iOS SDK by
# tool/sync_ios_sdk.dart), plus the Flutter bridge. No CocoaPods trunk dependency. Needs iOS 17.
Pod::Spec.new do |s|
  s.name             = 'devreply'
  s.version          = '0.4.2'
  s.summary          = "DevReply for Flutter: the native in-app chat between your app's users and you."
  s.homepage         = 'https://github.com/Code-Axolot-Team/devreply-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Code Axolot' => 'hello@devreply.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.swift', 'DevReplySDK/**/*.swift'
  s.resource_bundles = {
    'DevReply' => ['DevReplySDK/Resources/Fonts', 'DevReplySDK/Resources/Icons.xcassets', 'DevReplySDK/PrivacyInfo.xcprivacy']
  }
  s.dependency 'Flutter'
  s.platform = :ios, '17.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'
end
