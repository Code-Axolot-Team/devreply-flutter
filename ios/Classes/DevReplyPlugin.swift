import Flutter
import UIKit

/// The Flutter bridge: every call goes to the native DevReply SDK (compiled into this pod from
/// DevReplySDK/, the same sources as the iOS SDK). Flutter calls in on the main thread.
public final class DevReplyPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var sink: FlutterEventSink?
    private var observing = false
    private var configured = false
    /// A DevReply link that opened the app before Dart called configure.
    private var pendingLink: URL?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = DevReplyPlugin()
        let channel = FlutterMethodChannel(name: "devreply", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
        // The button in DevReply's emails opens the app with `yourapp://devreply?devreply=<id>`.
        registrar.addApplicationDelegate(instance)
        FlutterEventChannel(name: "devreply/unread", binaryMessenger: registrar.messenger()).setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        MainActor.assumeIsolated {
            switch call.method {
            case "configure":
                guard let key = args["key"] as? String else { return result(FlutterError(code: "key", message: "a public key is required", details: nil)) }
                DevReply.configure(key)
                configured = true
                observeUnread()
                if let link = pendingLink { _ = DevReply.handle(link) }
                pendingLink = nil
                result(nil)
            case "present":
                DevReply.present(category: (args["category"] as? String).flatMap(DevReplyCategory.init(rawValue:)))
                result(nil)
            case "setUser":
                DevReply.setUser(name: args["name"] as? String, email: args["email"] as? String)
                result(nil)
            case "setAttributes":
                var values: [String: DevReplyAttribute?] = [:]
                for (key, value) in args["attributes"] as? [String: Any] ?? [:] { values[key] = Self.attribute(value) }
                DevReply.setAttributes(values)
                result(nil)
            case "unreadCount":
                result(DevReply.unreadCount)
            case "setShowsUnreadBubble":
                DevReply.showsUnreadBubble = args["shows"] as? Bool ?? true
                result(nil)
            case "setLocale":
                DevReply.setLocale(args["tag"] as? String)
                result(nil)
            case "handle":
                result((args["url"] as? String).flatMap(URL.init(string:)).map { openLink($0) } ?? false)
            case "handlePush":
                // iOS shows DevReply's pushes itself (APNs).
                result(false)
            case "registerPushToken":
                if let hex = args["token"] as? String, let data = Self.data(hex: hex) { DevReply.registerPush(data) }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: DevReply links

    /// Opens the conversation a DevReply link points to; false for any other URL.
    @MainActor
    private func openLink(_ url: URL) -> Bool {
        let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "devreply" }?.value
        guard let id, UUID(uuidString: id) != nil else { return false }
        if configured { _ = DevReply.handle(url) } else { pendingLink = url }
        return true
    }

    public func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        MainActor.assumeIsolated { openLink(url) }
    }

    public func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([Any]) -> Void
    ) -> Bool {
        guard let url = userActivity.webpageURL else { return false }
        return MainActor.assumeIsolated { openLink(url) }
    }

    // MARK: Unread count stream

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        MainActor.assumeIsolated { events(DevReply.unreadCount) }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }

    /// Sends the count to Dart whenever it changes (Observation, re-armed after each change).
    @MainActor
    private func observeUnread() {
        guard !observing else { return }
        observing = true
        track(last: -1)
    }

    @MainActor
    private func track(last: Int) {
        let count = withObservationTracking { DevReply.unreadCount } onChange: { [weak self] in
            Task { @MainActor in self?.track(last: -2) }
        }
        if count != last { sink?(count) }
    }

    // MARK: Conversions

    private static func attribute(_ value: Any) -> DevReplyAttribute? {
        // Dart bools arrive as NSNumber too: tell them apart by their CF type.
        if let n = value as? NSNumber {
            return CFGetTypeID(n) == CFBooleanGetTypeID() ? .bool(n.boolValue) : .number(n.doubleValue)
        }
        if let s = value as? String { return .string(s) }
        return nil
    }

    private static func data(hex: String) -> Data? {
        let clean = hex.filter(\.isHexDigit)
        guard clean.count % 2 == 0, !clean.isEmpty else { return nil }
        var data = Data(capacity: clean.count / 2)
        var index = clean.startIndex
        while index < clean.endIndex {
            let next = clean.index(index, offsetBy: 2)
            guard let byte = UInt8(clean[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }
}
