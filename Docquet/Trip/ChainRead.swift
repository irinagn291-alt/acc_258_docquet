import SwiftUI

/// Role: Trip. Home twist surface. Shows the selected Job's lastEndMiles so the next trip can chain.
struct ChainRead: View {
    var job: Job
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: BlotterFace.space(1)) {
                Image("dcq_TwistHero")
                    .resizable()
                    .scaledToFit()
                    .frame(width: BlotterFace.tap, height: BlotterFace.tap)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Mileage chain")
                        .blotterText(.headline)
                    Text("\(job.name) starts at \(BlotterFigures.miles(job.lastEndMiles)). Cash does not move it.")
                        .blotterText(.caption)
                        .foregroundStyle(BlotterInk.Palette.muted)
                        .lineLimit(2)
                }
                Spacer(minLength: BlotterFace.space(1))
                Image(systemName: "chevron.right")
                    .foregroundStyle(BlotterInk.Palette.muted)
                    .accessibilityHidden(true)
            }
            .padding(BlotterFace.space(1))
            .frame(maxWidth: .infinity, minHeight: BlotterFace.tap, alignment: .leading)
            .contentShape(Rectangle())
            .blotterCard()
        }
        .buttonStyle(BlotterPressStyle())
        .accessibilityLabel("Mileage chain for \(job.name), starts at \(BlotterFigures.miles(job.lastEndMiles))")
        .accessibilityHint("Opens the chain for every project")
    }
}
