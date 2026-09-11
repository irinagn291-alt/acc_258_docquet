import SwiftUI
import UIKit

/// Role: Chain. Hairline+fill surfaces, 12/8 radii, 44pt hits. Reused by every pane.
enum BlotterMotion {
    static let curve: Animation = .easeInOut(duration: 0.25)

    static func fade(_ reduce: Bool) -> Animation? {
        reduce ? nil : curve
    }
}

struct BlotterPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(BlotterMotion.curve, value: configuration.isPressed)
    }
}

extension View {
    func blotterText(_ step: BlotterFace.Step) -> some View {
        font(step.font)
            .foregroundStyle(BlotterInk.Palette.ink)
    }

    func blotterCard() -> some View {
        background(BlotterInk.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: BlotterFace.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: BlotterFace.cardRadius, style: .continuous)
                    .stroke(BlotterInk.Palette.muted.opacity(0.35), lineWidth: BlotterFace.hairline)
            }
    }

    func blotterHeroCard() -> some View {
        background {
            ZStack {
                BlotterInk.Palette.surface
                Image("dcq_CardBackdrop")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.28)
                    .accessibilityHidden(true)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: BlotterFace.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BlotterFace.cardRadius, style: .continuous)
                .stroke(BlotterInk.Palette.muted.opacity(0.35), lineWidth: BlotterFace.hairline)
        }
    }

    func blotterChip(selected: Bool) -> some View {
        background(selected ? BlotterInk.Palette.accent.opacity(0.18) : BlotterInk.Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: BlotterFace.chipRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: BlotterFace.chipRadius, style: .continuous)
                    .stroke(
                        selected ? BlotterInk.Palette.accent : BlotterInk.Palette.muted.opacity(0.35),
                        lineWidth: BlotterFace.hairline
                    )
            }
    }

    func blotterHit() -> some View {
        frame(minWidth: BlotterFace.tap, minHeight: BlotterFace.tap)
            .contentShape(Rectangle())
    }

    func blotterScreen() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BlotterInk.Palette.background.ignoresSafeArea())
    }

    func blotterDismissKeyboard() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        )
    }
}
