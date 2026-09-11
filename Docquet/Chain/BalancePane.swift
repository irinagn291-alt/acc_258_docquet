import SwiftUI

/// Role: Chain. Balance is the books: billed versus personal by Job. Not a game tab.
struct BalancePane: View {
    @ObservedObject var session: DaybookSession
    var calendar: Calendar

    var body: some View {
        Group {
            if session.loadFailed {
                BlotterEmptyPage(
                    image: "dcq_EmptyList",
                    headline: "The books did not load",
                    line: "Retry to read billed versus personal for this month.",
                    actionTitle: "Retry",
                    enabled: !session.isBusy
                ) {
                    Task { await session.reload() }
                }
            } else if session.balanceIsEmpty {
                BlotterEmptyPage(
                    image: "dcq_EmptyList",
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
        .navigationTitle("Balance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(BlotterInk.Palette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var populated: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= 700
            Group {
                if wide {
                    HStack(alignment: .top, spacing: BlotterFace.space(2)) {
                        jobColumn
                            .frame(width: min(BlotterFace.space(52), proxy.size.width * 0.46))
                        booksColumn
                    }
                    .padding(.horizontal, BlotterFace.space(2))
                } else {
                    VStack(spacing: BlotterFace.space(1)) {
                        monthChrome
                        totals
                        if let warning = session.warning {
                            warningRow(warning)
                        }
                        jobList
                        cashMilesRow
                            .padding(.horizontal, BlotterFace.space(1))
                        monthBooks
                            .padding(.horizontal, BlotterFace.space(1))
                            .frame(maxHeight: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, wide ? BlotterFace.space(1) : 0)
            .padding(.bottom, BlotterFace.space(1))
        }
    }

    private var jobColumn: some View {
        VStack(spacing: BlotterFace.space(1)) {
            monthChrome
            totals
            if let warning = session.warning {
                warningRow(warning)
            }
            jobList
            monthBooks
                .padding(.horizontal, BlotterFace.space(1))
                .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var booksColumn: some View {
        VStack(alignment: .leading, spacing: BlotterFace.space(1)) {
            Text("This month on the books")
                .blotterText(.headline)
            Text("Filed days")
                .blotterText(.caption)
                .foregroundStyle(BlotterInk.Palette.muted)
            filedDays
            HStack(alignment: .top, spacing: BlotterFace.space(1)) {
                KindInkColumn(
                    title: "Cash billed",
                    figure: BlotterFigures.money(session.monthMix.cashBilled),
                    caption: "\(session.monthMix.cashCount) cash lines · File cash",
                    facts: cashFacts,
                    onHeader: session.openCashOnToday,
                    onOpen: session.openBooksTap
                )
                KindInkColumn(
                    title: "Miles billed",
                    figure: BlotterFigures.money(session.monthMix.milesBilled),
                    caption: "\(session.monthMix.tripCount) trips · File miles",
                    facts: milesFacts,
                    onHeader: session.openMilesOnToday,
                    onOpen: session.openBooksTap
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, BlotterFace.space(1))
    }

    private var monthBooks: some View {
        BooksMix(
            billed: session.monthMix.billed,
            personal: session.monthMix.personal,
            cashBilled: session.monthMix.cashBilled,
            milesBilled: session.monthMix.milesBilled,
            billedLine: "Folds into this month billed",
            personalLine: "Stays on the blotter, off billed",
            facts: monthFacts,
            showsSummary: false,
            onOpen: session.openBooksTap
        )
    }

    private var monthFacts: [BooksFact] {
        BooksFact.fromLines(
            session.monthInkLines,
            jobs: session.daybook.jobs,
            calendar: calendar,
            showDay: true
        )
    }

    private var cashFacts: [BooksFact] {
        BooksFact.fromLines(
            session.monthInkLines.filter { $0.kind == .cash },
            jobs: session.daybook.jobs,
            calendar: calendar,
            showDay: true
        )
    }

    private var milesFacts: [BooksFact] {
        BooksFact.fromLines(
            session.monthInkLines.filter { $0.kind == .miles },
            jobs: session.daybook.jobs,
            calendar: calendar,
            showDay: true
        )
    }

    private var monthChrome: some View {
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
                Text("Billed versus personal")
                    .blotterText(.headline)
                    .lineLimit(1)
                Text(BlotterFigures.monthTitle(session.visibleMonth, calendar: calendar))
                    .blotterText(.caption)
                    .foregroundStyle(BlotterInk.Palette.muted)
                    .lineLimit(1)
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
        .padding(.horizontal, BlotterFace.space(1))
        .padding(.top, BlotterFace.space(1))
    }

    private var totals: some View {
        let mix = session.monthMix
        return VStack(alignment: .leading, spacing: BlotterFace.space(1)) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Billed")
                    .blotterText(.caption)
                    .foregroundStyle(BlotterInk.Palette.muted)
                Text(BlotterFigures.money(mix.billed))
                    .blotterText(.figure)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(BlotterFace.space(2))
            .frame(maxWidth: .infinity, minHeight: BlotterFace.space(10), alignment: .leading)
            .blotterHeroCard()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Billed \(BlotterFigures.money(mix.billed))")
            HStack(alignment: .firstTextBaseline, spacing: BlotterFace.space(1)) {
                Text("Personal")
                    .blotterText(.callout)
                    .foregroundStyle(BlotterInk.Palette.muted)
                Spacer(minLength: BlotterFace.space(1))
                Text(BlotterFigures.money(mix.personal))
                    .blotterText(.figure)
                    .layoutPriority(1)
            }
            .padding(BlotterFace.space(2))
            .frame(maxWidth: .infinity, minHeight: BlotterFace.tap, alignment: .leading)
            .blotterCard()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Personal \(BlotterFigures.money(mix.personal))")
        }
        .padding(.horizontal, BlotterFace.space(1))
    }

    private var jobList: some View {
        VStack(spacing: BlotterFace.space(1)) {
            ForEach(session.books) { book in
                jobRow(book)
            }
        }
        .padding(.horizontal, BlotterFace.space(1))
    }

    private var cashMilesRow: some View {
        HStack(spacing: BlotterFace.space(1)) {
            Button(action: session.openCashOnToday) {
                mixTap(
                    title: "Cash billed",
                    figure: BlotterFigures.money(session.monthMix.cashBilled),
                    line: "\(session.monthMix.cashCount) cash lines · File cash"
                )
            }
            .buttonStyle(BlotterPressStyle())
            .accessibilityLabel("Cash billed \(BlotterFigures.money(session.monthMix.cashBilled))")
            .accessibilityHint("Opens today's blotter on cash")
            Button(action: session.openMilesOnToday) {
                mixTap(
                    title: "Miles billed",
                    figure: BlotterFigures.money(session.monthMix.milesBilled),
                    line: "\(session.monthMix.tripCount) trips · File miles"
                )
            }
            .buttonStyle(BlotterPressStyle())
            .accessibilityLabel("Miles billed \(BlotterFigures.money(session.monthMix.milesBilled))")
            .accessibilityHint("Opens today's blotter on miles")
        }
        .frame(maxWidth: .infinity)
    }

    private func mixTap(title: String, figure: String, line: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .blotterText(.caption)
                .foregroundStyle(BlotterInk.Palette.muted)
                .lineLimit(1)
            Text(figure)
                .blotterText(.figure)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(line)
                .blotterText(.caption)
                .foregroundStyle(BlotterInk.Palette.muted)
                .lineLimit(2)
        }
        .padding(BlotterFace.space(2))
        .frame(maxWidth: .infinity, minHeight: BlotterFace.tap, alignment: .leading)
        .contentShape(Rectangle())
        .blotterCard()
    }

    private var filedDays: some View {
        VStack(spacing: BlotterFace.space(1)) {
            ForEach(session.monthDayBooks) { book in
                Button {
                    session.openDayBlotter(book.daykey)
                } label: {
                    HStack(spacing: BlotterFace.space(1)) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(BlotterFigures.dayTitle(book.daykey, calendar: calendar))
                                .blotterText(.headline)
                                .lineLimit(1)
                            Text("Personal \(BlotterFigures.money(book.personal))")
                                .blotterText(.caption)
                                .foregroundStyle(BlotterInk.Palette.muted)
                                .lineLimit(1)
                        }
                        Spacer(minLength: BlotterFace.space(1))
                        Text(BlotterFigures.money(book.billed))
                            .blotterText(.figure)
                            .layoutPriority(1)
                    }
                    .padding(.horizontal, BlotterFace.space(2))
                    .frame(maxWidth: .infinity, minHeight: BlotterFace.tap, alignment: .leading)
                    .contentShape(Rectangle())
                    .blotterCard()
                }
                .buttonStyle(BlotterPressStyle())
                .accessibilityLabel(
                    "\(BlotterFigures.dayTitle(book.daykey, calendar: calendar)), billed \(BlotterFigures.money(book.billed)), personal \(BlotterFigures.money(book.personal))"
                )
                .accessibilityHint("Opens the blotter for this day")
            }
        }
    }

    private func jobRow(_ book: JobBooks) -> some View {
        let name = session.daybook.job(id: book.jobID)?.name ?? "Project"
        return Button {
            session.selectJob(book.jobID)
            session.openChain()
        } label: {
            VStack(alignment: .leading, spacing: BlotterFace.space(1)) {
                Text(name)
                    .blotterText(.headline)
                    .lineLimit(1)
                HStack(spacing: BlotterFace.space(1)) {
                    Text("Billed \(BlotterFigures.money(book.billed))")
                        .blotterText(.callout)
                        .lineLimit(1)
                    Spacer(minLength: BlotterFace.space(1))
                    Text("Personal \(BlotterFigures.money(book.personal))")
                        .blotterText(.callout)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
            }
            .padding(BlotterFace.space(2))
            .frame(maxWidth: .infinity, minHeight: BlotterFace.tap, alignment: .leading)
            .contentShape(Rectangle())
            .blotterCard()
        }
        .buttonStyle(BlotterPressStyle())
        .accessibilityLabel("\(name), billed \(BlotterFigures.money(book.billed)), personal \(BlotterFigures.money(book.personal))")
        .accessibilityHint("Opens the mileage chain")
    }

    private func warningRow(_ warning: DaybookWarning) -> some View {
        HStack(spacing: BlotterFace.space(1)) {
            Text(BlotterCopy.warning(warning))
                .blotterText(.callout)
            Spacer(minLength: BlotterFace.space(1))
            Button("Retry") {
                Task { await session.reload() }
            }
            .blotterText(.headline)
            .foregroundStyle(BlotterInk.Palette.accent)
            .blotterHit()
        }
        .padding(BlotterFace.space(1))
        .blotterCard()
        .padding(.horizontal, BlotterFace.space(1))
    }
}
