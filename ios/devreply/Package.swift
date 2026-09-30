// swift-tools-version: 5.9
// DevReply for Flutter with Swift Package Manager (Flutter's SwiftPM mode). The DevReply iOS SDK's sources
// are compiled into this target (DevReplySDK/, copied from the iOS SDK by tool/sync_ios_sdk.dart and
// carried in the published package), with the Flutter bridge: one module, `devreply`, like the CocoaPods
// build (../devreply.podspec). Needs iOS 17.
import PackageDescription

let package = Package(
    name: "devreply",
    platforms: [.iOS("17.0")],
    products: [
        .library(name: "devreply", targets: ["devreply"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "devreply",
            dependencies: [],
            resources: [
                .copy("DevReplySDK/PrivacyInfo.xcprivacy"),
                .copy("DevReplySDK/Resources/Fonts"),
                .process("DevReplySDK/Resources/Icons.xcassets"),
            ]
        ),
    ]
)
