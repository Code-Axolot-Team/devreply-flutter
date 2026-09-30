import Flutter
import SwiftUI
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
        FlutterEventChannel(name: "devreply/events", binaryMessenger: registrar.messenger()).setStreamHandler(instance.chatEvents)
    }

    /// What happens in the chat, for the app's analytics.
    private let chatEvents = ChatEvents()

    private static func theme(_ colors: [String: String]?, base: DevReplyTheme) -> DevReplyTheme {
        var t = base
        let c = { (key: String) in colors?[key].flatMap(color(hex:)) }
        if let v = c("primary") { t.primary = v }
        if let v = c("accent") { t.accent = v }
        if let v = c("userBubble") { t.userBubble = v }
        if let v = c("userBubbleText") { t.userBubbleText = v }
        if let v = c("background") { t.background = v }
        if let v = c("ink") { t.ink = v }
        return t
    }

    /// `#RRGGBBAA` (from Dart) or `#RRGGBB`.
    private static func color(hex: String) -> Color? {
        let clean = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard clean.count == 6 || clean.count == 8, let v = UInt64(clean, radix: 16) else { return nil }
        let rgba = clean.count == 6 ? (v << 8) | 0xFF : v
        return Color(.sRGB, red: Double((rgba >> 24) & 0xFF) / 255, green: Double((rgba >> 16) & 0xFF) / 255,
                     blue: Double((rgba >> 8) & 0xFF) / 255, opacity: Double(rgba & 0xFF) / 255)
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
                var attributes: [String: DevReplyAttribute] = [:]
                for (k, v) in args["attributes"] as? [String: Any] ?? [:] {
                    if let a = Self.attribute(v) { attributes[k] = a }
                }
                result(DevReply.present(
                    category: (args["category"] as? String).flatMap(DevReplyCategory.init(rawValue:)),
                    message: args["message"] as? String,
                    attributes: attributes,
                    askName: args["askName"] as? Bool ?? true
                ))
            case "isAvailable":
                result(DevReply.isAvailable)
            case "setTheme":
                switch args["lightMode"] as? String {
                case "reset": DevReply.theme = .light
                case "custom": DevReply.theme = Self.theme(args["light"] as? [String: String], base: .light)
                default: break
                }
                switch args["darkMode"] as? String {
                case "off": DevReply.darkTheme = nil
                case "default": DevReply.darkTheme = .dark
                case "custom": DevReply.darkTheme = Self.theme(args["dark"] as? [String: String], base: .dark)
                default: break
                }
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
            case "login":
                if let id = args["userId"] as? String { DevReply.login(userID: id) }
                result(nil)
            case "logout":
                DevReply.logout()
                result(nil)
            case "deleteUser":
                Task { @MainActor in result(await DevReply.deleteUser()) }
            case "setLocale":
                DevReply.setLocale(args["tag"] as? String)
                result(nil)
            case "handle":
                result((args["url"] as? String).flatMap(URL.init(string:)).map { openLink($0) } ?? false)
            case "handleNotificationOpened":
                result(DevReply.handleNotificationOpened(userInfo: args["data"] as? [String: Any] ?? [:]))
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

/// The chat's events for Dart (`DevReply.events`).
final class ChatEvents: NSObject, FlutterStreamHandler {
    private var sink: FlutterEventSink?
    private var subscription: DevReplySubscription?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        MainActor.assumeIsolated {
            guard subscription == nil else { return }
            subscription = DevReply.addEventListener { [weak self] event in
                switch event {
                case .messengerOpened: self?.sink?(["type": "messengerOpened"])
                case .messengerClosed: self?.sink?(["type": "messengerClosed"])
                case let .conversationStarted(id, category):
                    self?.sink?(["type": "conversationStarted", "conversationId": id.uuidString.lowercased(),
                                 "category": category?.rawValue as Any])
                case let .messageSent(id): self?.sink?(["type": "messageSent", "conversationId": id.uuidString.lowercased()])
                }
            }
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }
}
