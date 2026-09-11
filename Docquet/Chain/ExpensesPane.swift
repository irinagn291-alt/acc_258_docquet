import SwiftUI

/// Role: Chain. Expenses home. Month grid stays calendar-first. A selected day fuses the blotter on this screen so File, billable, and project sit in one glance.
struct ExpensesPane: View {
    @ObservedObject var session: DaybookSession
    var calendar: Calendar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if session.loadFailed {
                BlotterEmptyPage(
                    image: "dcq_EmptyHome",
                    headline: "The daybook did not load",
                    line: "Retry to read the last saved blotter on this device.",
                    actionTitle: "Retry",
                    enabled: !session.isBusy
                ) {
                    Task { await session.reload() }
                }
            } else if let warning = session.warning, !session.daybook.hasJobs, !session.daybook.hasInk {
                BlotterEmptyPage(
                    image: "dcq_EmptyHome",
                    headline: "The daybook could not be read",
                    line: BlotterCopy.warning(warning),
                    actionTitle: "Retry",
                    enabled: !session.isBusy
                ) {
                    Task { await session.reload() }
                }
            } else if session.expensesAreEmpty {
                BlotterEmptyPage(
                    image: "dcq_EmptyHome",
                    headline: "This month is empty",
                    line: "Log an expense or a trip.",
                    actionTitle: "File today's line",
                    enabled: !session.isBusy
                ) {
                    session.openTodayBlotter()
                }
            } else {
                populated
            }
        }
        .blotterScreen()
        .navigationTitle("Expenses")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(BlotterInk.Palette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: session.openChain) {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .frame(minWidth: BlotterFace.tap, minHeight: BlotterFace.tap)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BlotterPressStyle())
                .accessibilityLabel("Mileage chain")
            }
        }
    }

    private var populated: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= 700
            Group {
                if wide {
                    HStack(alignment: .top, spacing: BlotterFace.space(2)) {
                        boardColumn(compactGrid: false)
                        if session.selectedDay != nil {
                            InlineBlotter(session: session, compact: false)
                                .frame(width: min(BlotterFace.space(52), proxy.size.width * 0.42))
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .padding(.horizontal, BlotterFace.space(2))
                } else {
                    VStack(spacing: 0) {
                        boardColumn(compactGrid: session.selectedDay != nil)
                        if session.selectedDay != nil {
                            InlineBlotter(session: session, compact: true)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .animation(BlotterMotion.fade(reduceMotion), value: session.selectedDay)
    }

    private func boardColumn(compactGrid: Bool) -> some View {
        VStack(spacing: BlotterFace.space(1)) {
            if compactGrid {
                compactChrome
            } else {
                header
            }
            if let warning = session.warning {
                warningBanner(warning)
            }
            MonthBoard(
                cells: session.monthCells,
                selected: session.selectedDay,
                calendar: calendar,
                onSelect: { session.selectDay($0.daykey) }
            )
            .padding(.horizontal, BlotterFace.space(1))
            .frame(maxWidth: .infinity, minHeight: compactGrid ? compactGridHeight : BlotterFace.space(40), maxHeight: compactGrid ? compactGridHeight : .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: compactGrid ? nil : .infinity)
        .padding(.top, BlotterFace.space(1))
    }

    private var compactGridHeight: CGFloat {
        let weeks = CGFloat(max(1, MonthLattice.weeks(session.monthCells).count))
        return BlotterFace.space(3) + weeks * BlotterFace.tap
    }

    private var compactChrome: some View {
        HStack(spacing: BlotterFace.space(1)) {
            Button {
                session.pageMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: BlotterFace.tap, height: BlotterFace.tap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(BlotterPressStyle())
            .accessibilityLabel("Previous month")
            VStack(alignment: .leading, spacing: 0) {
                Text(BlotterFigures.monthTitle(session.visibleMonth, calendar: calendar))
                    .blotterText(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("This month billed")
                    .blotterText(.caption)
                    .foregroundStyle(BlotterInk.Palette.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(BlotterFigures.money(session.monthTotal))
                .blotterText(.figure)
                .layoutPriority(1)
            Button {
                session.pageMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: BlotterFace.tap, height: BlotterFace.tap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(BlotterPressStyle())
            .accessibilityLabel("Next month")
        }
        .padding(.horizontal, BlotterFace.space(1))
        .frame(maxWidth: .infinity, minHeight: BlotterFace.tap)
        .blotterHeroCard()
        .padding(.horizontal, BlotterFace.space(1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(BlotterFigures.monthTitle(session.visibleMonth, calendar: calendar)), this month billed \(BlotterFigures.money(session.monthTotal))"
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: BlotterFace.space(1)) {
            Image("dcq_HeaderDecor")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: BlotterFace.space(5))
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            monthPager(subtitle: session.homeHeadline)
            HStack(alignment: .firstTextBaseline, spacing: BlotterFace.space(1)) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("This month billed")
                        .blotterText(.caption)
                        .foregroundStyle(BlotterInk.Palette.muted)
                    Text(session.nextTapCopy)
                        .blotterText(.caption)
                        .foregroundStyle(BlotterInk.Palette.ink)
                        .lineLimit(2)
                }
                Spacer(minLength: BlotterFace.space(1))
                Text(BlotterFigures.money(session.monthTotal))
                    .blotterText(.figure)
                    .layoutPriority(1)
            }
            .padding(BlotterFace.space(2))
            .frame(maxWidth: .infinity, minHeight: BlotterFace.tap, alignment: .leading)
            .blotterHeroCard()
            .padding(.horizontal, BlotterFace.space(1))
            .accessibilityElement(children: .combine)
        }
    }

    private func monthPager(subtitle: String?) -> some View {
        HStack(spacing: BlotterFace.space(1)) {
            Button {
                session.pageMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: BlotterFace.tap, height: BlotterFace.tap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(BlotterPressStyle())
            .accessibilityLabel("Previous month")
            VStack(spacing: 0) {
                Text(BlotterFigures.monthTitle(session.visibleMonth, calendar: calendar))
                    .blotterText(.display)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let subtitle {
                    Text(subtitle)
                        .blotterText(.callout)
                        .foregroundStyle(BlotterInk.Palette.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            Button {
                session.pageMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: BlotterFace.tap, height: BlotterFace.tap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(BlotterPressStyle())
            .accessibilityLabel("Next month")
        }
    }

    private func warningBanner(_ warning: DaybookWarning) -> some View {
        HStack(spacing: BlotterFace.space(1)) {
            Text(BlotterCopy.warning(warning))
                .blotterText(.callout)
                .lineLimit(2)
            Spacer(minLength: BlotterFace.space(1))
            Button("Retry") {
                Task { await session.reload() }
            }
            .blotterText(.headline)
            .foregroundStyle(BlotterInk.Palette.accent)
            .blotterHit()
        }
        .padding(BlotterFace.space(1))
        .frame(maxWidth: .infinity)
        .blotterCard()
        .padding(.horizontal, BlotterFace.space(1))
    }
}
