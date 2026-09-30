# The DevReply iOS SDK (SwiftUI) compiled into this pod from devreply/Sources/devreply/DevReplySDK/ (copied
# from the iOS SDK by tool/sync_ios_sdk.dart), plus the Flutter bridge. No CocoaPods trunk dependency. The
# same files build with Swift Package Manager (devreply/Package.swift). Needs iOS 17.
Pod::Spec.new do |s|
  s.name             = 'devreply'
  s.version          = '0.5.1'
  s.summary          = "DevReply for Flutter: the native in-app chat between your app's users and you."
  s.homepage         = 'https://github.com/Code-Axolot-Team/devreply-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Code Axolot' => 'hello@devreply.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'devreply/Sources/devreply/**/*.swift'
  s.resource_bundles = {
    'DevReply' => ['devreply/Sources/devreply/DevReplySDK/Resources/Fonts', 'devreply/Sources/devreply/DevReplySDK/Resources/Icons.xcassets', 'devreply/Sources/devreply/DevReplySDK/PrivacyInfo.xcprivacy']
  }
  s.dependency 'Flutter'
  s.platform = :ios, '17.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'
end
