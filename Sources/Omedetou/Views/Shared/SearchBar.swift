import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    /// Set to a locale ("ja-JP") to put a mic in the field. Off everywhere by
    /// default: only searches where saying the word beats typing it — which in
    /// practice means the ones you'd otherwise switch keyboards for — should
    /// ask for the microphone.
    var dictationLocale: String?

    @ObservedObject private var dictation = DictationService.shared

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 15))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .disableAutocorrection(true)
                .autocapitalization(.none)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if let locale = dictationLocale {
                Button {
                    dictation.toggle(locale: locale) { text = $0 }
                } label: {
                    Image(systemName: dictation.isListening ? "waveform" : "mic.fill")
                        .font(.system(size: 15))
                        .foregroundColor(dictation.isListening ? .appAccent : .secondary)
                        .symbolEffectPulse(dictation.isListening)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(dictation.isListening ? "Stop listening" : "Search by voice")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.appSurfaceHigh)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.appHairline, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        // Never leave the mic open behind a screen the user has walked away from.
        .onDisappear { if dictationLocale != nil { dictation.stop() } }
        // Only the bar that owns a mic reports its problems. Every search field
        // in the app is one of these, and without the guard an undismissed
        // failure from somewhere else would surface on the next one shown.
        .alert("Voice search", isPresented: Binding(
            get: { dictationLocale != nil && dictation.problem != nil },
            set: { if !$0 { dictation.problem = nil } }
        )) {
            Button("OK", role: .cancel) { dictation.problem = nil }
        } message: {
            Text(dictation.problem?.message ?? "")
        }
    }
}
