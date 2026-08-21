import SwiftUI

// Write something, send it, leave. Nothing else.
//
// No mail app opens, no address is shown, and the only outcome the screen
// reports is "Sent" or a reason it couldn't be. Deliberately plain: a feedback
// box that asks for a name, an email and a category is a feedback box nobody
// fills in.

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var status: Status = .idle
    @FocusState private var writing: Bool

    private enum Status: Equatable {
        case idle, sending, sent
        case failed(String)
    }

    private var remaining: Int { FeedbackService.characterLimit - text.count }
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && remaining >= 0 && status != .sending && status != .sent
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Found a mistake, or want something added? Tell me here.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.appText)

                    editor

                    // Said before they type, not after: the honest place for it.
                    Label("Only what you write here is sent, along with the app and iOS version. Please don't include personal details.",
                          systemImage: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.appTextSecondary)
                        .labelStyle(.titleAndIcon)

                    submitRow

                    if case let .failed(why) = status {
                        banner(why, ok: false)
                    } else if status == .sent {
                        banner("Sent — thank you.", ok: true)
                    }

                    if !FeedbackService.isConfigured {
                        Text("This build has no feedback key set, so nothing will send.")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "C0392B"))
                    }
                }
                .padding(18)
            }
        }
        .standardNavBar("Send Feedback")
        .onAppear { writing = true }
    }

    private var editor: some View {
        VStack(alignment: .trailing, spacing: 4) {
            TextEditor(text: $text)
                .focused($writing)
                .font(.system(size: 15))
                .foregroundColor(.appText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 190)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.appSurface))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.appHairline, lineWidth: 1))
                .disabled(status == .sending || status == .sent)

            Text("\(max(remaining, 0))")
                .font(.system(size: 11).monospacedDigit())
                .foregroundColor(remaining < 0 ? Color(hex: "C0392B") : .appTextSecondary)
        }
    }

    private var submitRow: some View {
        HStack(spacing: 12) {
            Button(action: submit) {
                HStack(spacing: 8) {
                    if status == .sending {
                        ProgressView().controlSize(.small).tint(.white)
                    }
                    Text(status == .sending ? "Sending…" : (status == .sent ? "Sent" : "Submit"))
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(canSend || status == .sent ? Color.appAccent : Color.appAccent.opacity(0.35)))
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)

            if status == .sent {
                Button("Done") { FeedbackSounds.shared.playNavigate(); dismiss() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appAccent)
            }
        }
    }

    private func banner(_ message: String, ok: Bool) -> some View {
        Label(message, systemImage: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(ok ? Color(hex: "3B9A55") : Color(hex: "C0392B"))
            .padding(.top, 2)
    }

    private func submit() {
        writing = false
        status = .sending
        Task {
            do {
                try await FeedbackService.send(text)
                status = .sent
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }
}
