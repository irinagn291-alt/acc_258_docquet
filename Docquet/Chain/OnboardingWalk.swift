import SwiftUI

/// Role: Chain. Three-to-four pages. Skip still writes the completion flag. Re-runnable from Settings.
struct OnboardingWalk: View {
    var onFinish: () -> Void
    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let lastPage = 3

    var body: some View {
        VStack(spacing: BlotterFace.space(2)) {
            Group {
                switch page {
                case 0:
                    pageView(
                        image: "dcq_Onboarding1",
                        title: "Tap a day",
                        line: "Docquet is a daybook for cash and miles by project. Open a cell on the month grid — not a list of invoices."
                    )
                case 1:
                    pageView(
                        image: "dcq_Onboarding2",
                        title: "File the line",
                        line: "Cash writes an amount. Miles write start and end odometer. File keeps the line on this device."
                    )
                case 2:
                    pageView(
                        image: "dcq_Onboarding3",
                        title: "Billed versus personal",
                        line: "Mark a line billable and it folds into this month's Balance. Personal stays on the blotter and out of the billed total."
                    )
                default:
                    pageView(
                        image: "dcq_TwistHero",
                        title: "The mileage chain",
                        line: "A trip starts at that project's last end reading. Distance is end minus start. Cash never moves the chain."
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(BlotterMotion.fade(reduceMotion), value: page)

            Button {
                if page < lastPage {
                    page += 1
                } else {
                    onFinish()
                }
            } label: {
                Text(page < lastPage ? "Continue" : "Start")
                    .blotterText(.headline)
                    .foregroundStyle(BlotterInk.Palette.surface)
                    .frame(maxWidth: .infinity, minHeight: BlotterFace.tap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderedProminent)
            .tint(BlotterInk.Palette.accent)
            .controlSize(.large)

            Button("Skip") { onFinish() }
                .blotterText(.body)
                .foregroundStyle(BlotterInk.Palette.muted)
                .frame(maxWidth: .infinity, minHeight: BlotterFace.tap)
                .contentShape(Rectangle())
        }
        .padding(BlotterFace.space(2))
        .blotterScreen()
    }

    private func pageView(image: String, title: String, line: String) -> some View {
        VStack(spacing: BlotterFace.space(2)) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 280)
                .padding(BlotterFace.space(2))
                .background(BlotterInk.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: BlotterFace.cardRadius, style: .continuous))
                .accessibilityHidden(true)
            Text(title)
                .blotterText(.display)
                .multilineTextAlignment(.center)
            Text(line)
                .blotterText(.body)
                .foregroundStyle(BlotterInk.Palette.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, BlotterFace.space(1))
    }
}
