import SwiftUI

/// Role: Trip. Twist screen. Each Job's lastEndMiles and last odometer pair. Cash outlays are absent on purpose.
struct OdometerPane: View {
    @ObservedObject var session: DaybookSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if session.chainCards.isEmpty {
                    BlotterEmptyPage(
                        image: "dcq_TwistHero",
                        headline: "No mileage chain yet",
                        line: "Add a project, then file miles. The next trip starts at that project's last end reading.",
                        actionTitle: "File today's line",
                        enabled: !session.isBusy
                    ) {
                        dismiss()
                        session.openTodayBlotter()
                    }
                } else {
                    populated
                }
            }
            .blotterScreen()
            .navigationTitle("Mileage chain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(BlotterInk.Palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .frame(minWidth: BlotterFace.tap, minHeight: BlotterFace.tap)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(BlotterPressStyle())
                    .accessibilityLabel("Close")
                }
            }
        }
        .presentationBackground(BlotterInk.Palette.background)
    }

    private var populated: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BlotterFace.space(2)) {
                Image("dcq_TwistHero")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: BlotterFace.space(22))
                    .frame(maxWidth: .infinity)
                    .padding(BlotterFace.space(2))
                    .background(BlotterInk.Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: BlotterFace.cardRadius, style: .continuous))
                    .accessibilityHidden(true)
                Text("A trip writes start and end miles. Filing it advances last end. A cash outlay skips the chain.")
                    .blotterText(.body)
                    .foregroundStyle(BlotterInk.Palette.muted)
                ForEach(session.chainCards) { card in
                    chainRow(card)
                }
            }
            .padding(BlotterFace.space(2))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.immediately)
        .contentMargins(.bottom, BlotterFace.space(2))
    }

    private func chainRow(_ card: ChainCard) -> some View {
        VStack(alignment: .leading, spacing: BlotterFace.space(1)) {
            HStack(alignment: .firstTextBaseline, spacing: BlotterFace.space(1)) {
                Text(card.job.name)
                    .blotterText(.headline)
                    .lineLimit(1)
                Spacer(minLength: BlotterFace.space(1))
                Text(BlotterFigures.miles(card.job.lastEndMiles))
                    .blotterText(.figure)
                    .layoutPriority(1)
            }
            if let trip = card.lastTrip {
                Text(
                    "Last trip \(BlotterFigures.miles(trip.startMiles)) → \(BlotterFigures.miles(trip.endMiles)), distance \(BlotterFigures.miles(trip.distance)) at \(BlotterFigures.rate(trip.snapshottedRate.perMile))."
                )
                .blotterText(.caption)
                .foregroundStyle(BlotterInk.Palette.muted)
            } else {
                Text("No miles filed. The next trip starts at \(BlotterFigures.miles(card.job.lastEndMiles)).")
                    .blotterText(.caption)
                    .foregroundStyle(BlotterInk.Palette.muted)
            }
            Button {
                session.selectJob(card.job.id)
                session.selectKind(.miles)
                dismiss()
                session.openTodayBlotter()
            } label: {
                Text("File miles for \(card.job.name)")
                    .blotterText(.callout)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: BlotterFace.tap)
                    .contentShape(Rectangle())
                    .blotterChip(selected: session.jobID == card.job.id)
            }
            .buttonStyle(BlotterPressStyle())
        }
        .padding(BlotterFace.space(2))
        .frame(maxWidth: .infinity, alignment: .leading)
        .blotterCard()
        .accessibilityElement(children: .contain)
    }
}
