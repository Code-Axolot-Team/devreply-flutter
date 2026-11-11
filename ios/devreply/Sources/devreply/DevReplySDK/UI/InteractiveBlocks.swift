import SwiftUI

// SDK 0.6 (spec 14): link buttons, gifts, forms and offers in team messages, in the Loud look. Links open with
// the system (`openURL`), so the app's own deep-link handling does the rest; DevReply calls no app code.

// MARK: - Link buttons

/// 1 to 3 outlined buttons under the intro, like the answers of a button question, each with an arrow: it
/// leaves the chat. `onTap` reports the tap and returns the URL to open (nil = not allowed: nothing opens).
struct LinkButtons: View {
    let links: [LinkButton]
    let onTap: (LinkButton) -> URL?
    @Environment(\.openURL) private var openURL
    private var palette: Palette { Palette.active }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(links) { link in
                Button {
                    if let url = onTap(link) { openURL(url) }
                } label: {
                    HStack(spacing: 10) {
                        Text(link.label)
                            .font(.text(16, .bold))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .black))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(palette.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .frame(minHeight: 44)
                }
                .buttonStyle(BrutalPressStyle(shadow: 3))
                .accessibilityIdentifier("devreply.link.\(link.id)")
                .accessibilityAddTraits(.isLink)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Gift

/// A wrapped box: a pink lid with a lemon ribbon and the gift on it, then the title, the line and "Open gift".
/// After it expires the button gives way to "This gift has expired" and the lid goes grey.
struct GiftCard: View {
    @Environment(\.devReplyLine) private var line
    let gift: Gift
    /// Reports the opening and returns the URL to open (nil = expired or not allowed).
    let onOpen: () -> URL?
    @Environment(\.openURL) private var openURL
    private var palette: Palette { Palette.active }

    var body: some View {
        // Checked when drawn: the thread redraws every few seconds while it's open.
        let expired = gift.isExpired()
        VStack(alignment: .leading, spacing: 0) {
            lid
                .saturation(expired ? 0 : 1)
                .opacity(expired ? 0.55 : 1)
            VStack(alignment: .leading, spacing: 8) {
                Kicker(text: t("gift.label"), inverted: true)
                Text(gift.title)
                    .font(.display(22, relativeTo: .title2))
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !gift.text.isEmpty {
                    Text(gift.text)
                        .font(.text(16, .medium))
                        .foregroundStyle(palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if expired {
                    Text(t("gift.expired"))
                        .font(.text(15, .bold))
                        .foregroundStyle(palette.muted)
                        .padding(.top, 6)
                        .accessibilityIdentifier("devreply.gift.expired")
                } else {
                    Button {
                        if let url = onOpen() { openURL(url) }
                    } label: {
                        Text(t("gift.open"))
                            .font(.text(16, .bold))
                            .foregroundStyle(palette.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                    }
                    .buttonStyle(BrutalPressStyle(fill: palette.accent, shadow: 3))
                    .padding(.top, 6)
                    .padding(.trailing, 3)
                    .accessibilityIdentifier("devreply.gift.open")
                }
            }
            .padding(14)
        }
        .frame(maxWidth: 300, alignment: .leading)
        .brutal(shadow: 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("devreply.gift")
    }

    /// The box's lid: pink paper, a lemon ribbon down the middle, the gift icon on the ribbon.
    private var lid: some View {
        ZStack {
            palette.accent
            Rectangle()
                .fill(Brand.lemon)
                .frame(width: 26)
                .overlay(
                    HStack {
                        Rectangle().fill(palette.outline).frame(width: 2.5 * line)
                        Spacer()
                        Rectangle().fill(palette.outline).frame(width: 2.5 * line)
                    }
                )
            Image(systemName: "gift.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Brand.ink)
                .frame(width: 46, height: 46)
                .background(Brand.lemon)
                .overlay(Rectangle().strokeBorder(palette.outline, lineWidth: 2.5 * line))
                .accessibilityHidden(true)
        }
        .frame(height: 72)
        .overlay(alignment: .bottom) { Rectangle().fill(palette.outline).frame(height: 3 * line) }
    }
}

// MARK: - Form

/// Several questions in one card: one choice, any choices ("Pick any"), or a few words. Send posts them once;
/// a required question left empty says "Please answer this one." Once answered, the card shows the answers,
/// read-only (from the thread, or at once after Send).
struct FormCard: View {
    @Environment(\.devReplyLine) private var line
    let form: FormBlock
    let message: Message
    let model: ConversationModel
    private var palette: Palette { Palette.active }

    private var answered: [String: FormValue]? { model.formAnswers[message.id] }
    private var draft: [String: FormValue] { model.formDrafts[message.id] ?? [:] }
    private var missing: Set<String> { model.formMissing[message.id] ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(form.questions) { question in
                questionView(question)
            }
            if answered == nil {
                Button { model.submit(form, of: message) } label: {
                    Text(t("form.send"))
                        .font(.text(16, .bold))
                        .foregroundStyle(palette.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(BrutalPressStyle(fill: palette.accent, shadow: 3))
                .padding(.trailing, 3)
                .accessibilityIdentifier("devreply.form.send")
            }
        }
        .padding(14)
        .brutal(fill: palette.teamBubble, shadow: 3, lineWidth: 2.5, cornerRadius: 14)
        .animation(.snappy(duration: 0.2), value: answered)
        .animation(.snappy(duration: 0.2), value: missing)
    }

    @ViewBuilder private func questionView(_ question: FormQuestion) -> some View {
        let given = answered.flatMap { form.answer(for: question, in: $0) }
        VStack(alignment: .leading, spacing: 8) {
            Text(question.text)
                .font(.text(16, .bold))
                .foregroundStyle(palette.teamBubbleText)
                .fixedSize(horizontal: false, vertical: true)
            if question.kind == .multi, answered == nil {
                Text(t("form.pick_any"))
                    .font(.text(13, .medium, relativeTo: .footnote))
                    .foregroundStyle(palette.muted)
            }
            switch question.kind {
            case .single, .multi:
                options(question, chosen: answered == nil ? draft[question.id]?.ids ?? [] : given?.ids ?? [])
            case .text:
                if answered != nil {
                    Text(given.flatMap { if case .one(let text) = $0 { text } else { nil } } ?? "—")
                        .font(.text(16, .medium))
                        .foregroundStyle(palette.teamBubbleText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.teamBubbleText.opacity(0.06))
                        .overlay(Rectangle().strokeBorder(palette.outline.opacity(0.35), lineWidth: 1.5 * line))
                        .accessibilityIdentifier("devreply.form.\(question.id).answer")
                } else {
                    // One line: Return puts the keyboard away, so Send is in reach again.
                    TextField(t("form.your_answer"), text: textBinding(question), prompt: Text(t("form.your_answer")))
                        .font(.text(16))
                        .foregroundStyle(palette.ink)
                        .tint(palette.ink)
                        .submitLabel(.done)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(minHeight: 44)
                        .background(palette.surface)
                        .overlay(Rectangle().strokeBorder(palette.outline, lineWidth: 2.5 * line))
                        .accessibilityIdentifier("devreply.form.\(question.id).text")
                }
            }
            if answered == nil, missing.contains(question.id) {
                Label(t("form.required"), systemImage: "exclamationmark.triangle.fill")
                    .font(.text(13, .bold, relativeTo: .footnote))
                    .foregroundStyle(palette.error)
                    .accessibilityIdentifier("devreply.form.\(question.id).required")
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// Single: a tap picks one (another tap on it unpicks). Multi: each tap toggles. Answered: the chosen
    /// ones stay filled with a check, the others go quiet; nothing can be tapped.
    private func options(_ question: FormQuestion, chosen: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(question.options) { option in
                let isChosen = chosen.contains(option.id)
                Button { toggle(option.id, in: question, chosen: chosen) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: indicator(question.kind, isChosen))
                            .font(.system(size: 15, weight: .bold))
                            .accessibilityHidden(true)
                        Text(option.label)
                            .font(.text(15, .bold))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(isChosen ? palette.onAccent : palette.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(minHeight: 42)
                }
                .buttonStyle(BrutalPressStyle(fill: isChosen ? palette.accent : nil, shadow: answered == nil || isChosen ? 2 : 0))
                .opacity(answered == nil || isChosen ? 1 : 0.4)
                .disabled(answered != nil)
                .padding(.trailing, 2)
                .accessibilityIdentifier("devreply.form.\(question.id).\(option.id)")
                .accessibilityAddTraits(isChosen ? .isSelected : [])
            }
        }
    }

    private func indicator(_ kind: FormQuestion.Kind, _ on: Bool) -> String {
        switch (kind, on) {
        case (.multi, true): "checkmark.square.fill"
        case (.multi, false): "square"
        case (_, true): "checkmark.circle.fill"
        case (_, false): "circle"
        }
    }

    private func toggle(_ id: String, in question: FormQuestion, chosen: [String]) {
        guard answered == nil else { return }
        let value: FormValue? = switch question.kind {
        case .single: chosen == [id] ? nil : .one(id)
        case .multi: chosen.contains(id) ? (chosen.count == 1 ? nil : .many(chosen.filter { $0 != id })) : .many(chosen + [id])
        case .text: nil
        }
        model.setDraft(value, question: question.id, form: message.id)
    }

    private func textBinding(_ question: FormQuestion) -> Binding<String> {
        Binding(
            get: { if case .one(let text) = draft[question.id] { text } else { "" } },
            set: { model.setDraft($0.isEmpty ? nil : .one($0), question: question.id, form: message.id) }
        )
    }
}

// MARK: - Offers

/// Under a promotional message: "Don't send me offers"; after a tap, "You won't get offers." with Undo. The
/// state is the profile's `no_promotions`, so every offer in the chat says the same.
struct OfferOptOut: View {
    @State private var saving = false
    private var palette: Palette { Palette.active }
    private var optedOut: Bool { Messenger.shared.profile?.noPromotions == true }

    var body: some View {
        HStack(spacing: 6) {
            if optedOut {
                Text(t("offer.opted_out"))
                    .foregroundStyle(palette.muted)
                    .accessibilityIdentifier("devreply.offer.opted_out")
                Button(t("offer.undo")) { set(false) }
                    .underline()
                    .foregroundStyle(palette.ink)
                    .accessibilityIdentifier("devreply.offer.undo")
            } else {
                Button(t("offer.opt_out")) { set(true) }
                    .underline()
                    .foregroundStyle(palette.muted)
                    .accessibilityIdentifier("devreply.offer.opt_out")
            }
        }
        .font(.text(13, .bold, relativeTo: .footnote))
        .buttonStyle(.plain)
        .disabled(saving)
        .frame(minHeight: 28)
    }

    private func set(_ value: Bool) {
        saving = true
        Task {
            await Messenger.shared.setNoPromotions(value)
            saving = false
        }
    }
}
