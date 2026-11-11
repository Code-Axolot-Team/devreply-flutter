import Foundation
import UserNotifications

// SDK 0.6 (spec 14, "0.6 wire formats"): link buttons, gifts and forms in team messages. Each block carries
// `min_sdk: "0.6.0"` and a plain-text `fallback` (older SDKs show it); a malformed one shows its fallback too.

// MARK: - Which links open

/// Links open only when they're `https`, or use one of the app's own deep-link schemes (`link_schemes` in the
/// config, Settings → deep link in the dashboard). Anything else (http, other apps' schemes, `javascript:`…)
/// is never opened.
enum LinkPolicy {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var current: [String] = []

    /// The app's schemes from the config this install has now (cached or fresh). Read while decoding
    /// messages, which happens off the main actor.
    static var appSchemes: [String] {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue.map { $0.lowercased() } } }
    }

    /// A link button's or a gift's URL: https with a host, or one of `schemes`.
    static func isAllowed(_ url: URL, schemes: [String] = appSchemes) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "https" { return !(url.host() ?? "").isEmpty }
        return schemes.contains(scheme)
    }

    static func isAllowed(_ text: String, schemes: [String] = appSchemes) -> Bool {
        URL(string: text).map { isAllowed($0, schemes: schemes) } ?? false
    }
}

// MARK: - Link buttons (`links`)

/// One button of a `links` block: what it says and where it goes.
struct LinkButton: Decodable, Sendable, Equatable, Identifiable {
    let id: String
    let label: String
    let url: String

    private enum Keys: String, CodingKey { case id, label, url }

    /// All three needed, none blank; a button without them is left out.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let id = try c.decode(String.self, forKey: .id)
        let label = try c.decode(String.self, forKey: .label)
        let url = try c.decode(String.self, forKey: .url).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, URL(string: url) != nil else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "link without id, label or url"))
        }
        self.id = id
        self.label = label
        self.url = url
    }

    init(id: String, label: String, url: String) {
        self.id = id
        self.label = label
        self.url = url
    }
}

// MARK: - Gift (`gift`)

/// A gift card: its title and line, the deep link it opens (with the one-time `devreply_gift` token the app
/// checks before granting anything), and when it expires.
struct Gift: Sendable, Equatable {
    let id: UUID
    let title: String
    let text: String
    /// Carries a one-time token: never logged.
    let url: String
    let expiresAt: Date?

    func isExpired(at now: Date = Date()) -> Bool {
        expiresAt.map { $0 <= now } ?? false
    }
}

// MARK: - Several questions (`form`)

struct FormQuestion: Decodable, Sendable, Equatable, Identifiable {
    enum Kind: String, Sendable, Equatable { case single, multi, text }

    let id: String
    let text: String
    let kind: Kind
    /// For `single` and `multi`; empty for `text`.
    let options: [ButtonOption]
    let required: Bool

    private enum Keys: String, CodingKey { case id, text, kind, options, required }

    /// Strict: a question this SDK can't show (unknown kind, no options) fails, and the whole form shows its
    /// fallback (answering only some questions would be refused anyway).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = try c.decode(String.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        guard let kind = Kind(rawValue: try c.decode(String.self, forKey: .kind)), !id.isEmpty else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "unknown question"))
        }
        self.kind = kind
        options = kind == .text ? [] : (((try? c.decodeIfPresent(Lossy<ButtonOption>.self, forKey: .options)) ?? nil)?.items ?? [])
        guard kind == .text || !options.isEmpty else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "choice without options"))
        }
        required = ((try? c.decodeIfPresent(Bool.self, forKey: .required)) ?? nil) ?? false
    }

    init(id: String, text: String, kind: Kind, options: [ButtonOption] = [], required: Bool = false) {
        self.id = id
        self.text = text
        self.kind = kind
        self.options = options
        self.required = required
    }
}

struct FormBlock: Sendable, Equatable {
    /// The Markdown intro, parsed (may be empty), and its plain text.
    let intro: [MarkdownBlock]
    let plain: String
    let questions: [FormQuestion]

    /// What gets sent, from what the user picked and typed: text trimmed, choices in the question's order and
    /// only ids it knows, unanswered questions left out.
    func answers(from draft: [String: FormValue]) -> [String: FormValue] {
        var out: [String: FormValue] = [:]
        for question in questions {
            guard let value = draft[question.id] else { continue }
            switch (question.kind, value) {
            case (.text, .one(let text)):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { out[question.id] = .one(trimmed) }
            case (.single, .one(let id)) where question.options.contains(where: { $0.id == id }):
                out[question.id] = .one(id)
            case (.multi, .many(let ids)):
                let picked = question.options.map(\.id).filter(ids.contains)
                if !picked.isEmpty { out[question.id] = .many(picked) }
            default:
                break
            }
        }
        return out
    }

    /// Required questions without an answer (in `answers`, as `answers(from:)` returns them).
    func missing(in answers: [String: FormValue]) -> [String] {
        questions.filter { $0.required && answers[$0.id] == nil }.map(\.id)
    }

    /// An answer as the thread gives it back. The API decoder turns snake_case keys into camelCase, the keys of
    /// `answers` too, so a question id with an underscore is also looked up the way it arrives.
    func answer(for question: FormQuestion, in answers: [String: FormValue]) -> FormValue? {
        answers[question.id] ?? answers[FormBlock.camelCased(question.id)]
    }

    /// `JSONDecoder.KeyDecodingStrategy.convertFromSnakeCase`, for one key.
    static func camelCased(_ key: String) -> String {
        let parts = key.split(separator: "_", omittingEmptySubsequences: true)
        guard parts.count > 1, let first = parts.first else { return key }
        return String(first) + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    /// Readable lines for the answer while it sends ("What stopped you? Price"), like the server's summary.
    func summary(of answers: [String: FormValue]) -> String {
        questions.compactMap { question -> String? in
            guard let value = answers[question.id] else { return nil }
            let label = { (id: String) in question.options.first { $0.id == id }?.label ?? id }
            let shown = switch value {
            case .one(let v): question.kind == .text ? v : label(v)
            case .many(let ids): ids.map(label).joined(separator: ", ")
            }
            return "\(question.text) \(shown)"
        }
        .joined(separator: "\n")
    }
}

/// One answer: an option id (`single`), several (`multi`) or what the user wrote (`text`).
enum FormValue: Codable, Sendable, Equatable, Hashable {
    case one(String)
    case many([String])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let text = try? c.decode(String.self) { self = .one(text) } else { self = .many(try c.decode([String].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .one(let text): try c.encode(text)
        case .many(let ids): try c.encode(ids)
        }
    }

    var ids: [String] {
        switch self {
        case .one(let id): [id]
        case .many(let ids): ids
        }
    }
}

/// The user's answers to a form (`POST …/messages {"form_answer": …}`), and what the thread gives back on the
/// answer message's block.
struct FormAnswer: Codable, Sendable, Equatable {
    let messageId: UUID
    let answers: [String: FormValue]

    init(messageId: UUID, answers: [String: FormValue]) {
        self.messageId = messageId
        self.answers = answers
    }

    private enum Keys: String, CodingKey {
        // Decoded with `convertFromSnakeCase` (API responses); encoded as the server spells it.
        case messageId, answers
        case messageIdWire = "message_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        messageId = try (try? c.decode(UUID.self, forKey: .messageId)) ?? c.decode(UUID.self, forKey: .messageIdWire)
        answers = ((try? c.decodeIfPresent([String: FormValue].self, forKey: .answers)) ?? nil) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(messageId.uuidString.lowercased(), forKey: .messageIdWire)
        try c.encode(answers, forKey: .answers)
    }
}

// MARK: - Notification permission (`PATCH /v1/install {"push_permission"}`)

enum PushPermission {
    /// What the server keeps: `allowed` (ephemeral too, App Clips), `denied`, `not_asked`, `provisional`.
    /// A status newer than this SDK isn't sent.
    static func value(for status: UNAuthorizationStatus) -> String? {
        switch status {
        case .notDetermined: "not_asked"
        case .denied: "denied"
        case .authorized, .ephemeral: "allowed"
        case .provisional: "provisional"
        @unknown default: nil
        }
    }

    /// Sent again only when it changed for this install: the last value sent, with a fingerprint of the install
    /// token it went with (a new install, after a logout or a revoked token, gets it again). Never the token.
    static func stored(_ value: String, token: String) -> String {
        "\(value) \(fingerprint(token))"
    }

    /// FNV-1a, 64 bits: enough to tell two tokens apart, nothing to recover one from.
    static func fingerprint(_ token: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in token.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01b3
        }
        return String(hash, radix: 16)
    }
}
