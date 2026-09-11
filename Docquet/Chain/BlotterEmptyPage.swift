import SwiftUI

/// Role: Chain. Full-page empty or error. Art, headline, one line, bottom full-width CTA.
struct BlotterEmptyPage: View {
    var image: String
    var headline: String
    var line: String
    var actionTitle: String
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        VStack(spacing: BlotterFace.space(2)) {
            VStack(spacing: BlotterFace.space(2)) {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240, maxHeight: 240)
                    .padding(BlotterFace.space(2))
                    .background(BlotterInk.Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: BlotterFace.cardRadius, style: .continuous))
                    .accessibilityHidden(true)
                Text(headline)
                    .blotterText(.headline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Text(line)
                    .blotterText(.body)
                    .foregroundStyle(BlotterInk.Palette.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button(action: action) {
                Text(actionTitle)
                    .blotterText(.headline)
                    .foregroundStyle(BlotterInk.Palette.surface)
                    .frame(maxWidth: .infinity, minHeight: BlotterFace.tap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderedProminent)
            .tint(BlotterInk.Palette.accent)
            .controlSize(.large)
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.45)
        }
        .padding(BlotterFace.space(2))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BlotterInk.Palette.background)
    }
}
