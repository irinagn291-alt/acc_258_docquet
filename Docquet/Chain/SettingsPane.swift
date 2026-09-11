import SwiftUI

/// Role: Chain. Settings. Contact URL, local CSV export, reset, re-run onboarding. No WebView.
struct SettingsPane: View {
    @ObservedObject var session: DaybookSession
    var calendar: Calendar
    @State private var confirmReset = false

    var body: some View {
        Group {
            if session.loadFailed {
                BlotterEmptyPage(
                    image: "dcq_EmptyList",
                    headline: "Settings could not load",
                    line: "Retry to reach contact, export, and reset.",
                    actionTitle: "Retry",
                    enabled: !session.isBusy
                ) {
                    Task { await session.reload() }
                }
            } else {
                populated
            }
        }
        .blotterScreen()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(BlotterInk.Palette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .confirmationDialog("Erase every filed line?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset all data", role: .destructive) {
                Task { await session.resetAll() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var populated: some View {
        GeometryReader { proxy in
            let wide = proxy.size.width >= 700
            VStack(spacing: BlotterFace.space(2)) {
                actionsBlock(wide: wide)
                helpColumn
            }
            .padding(BlotterFace.space(2))
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }

    private func actionsBlock(wide: Bool) -> some View {
        let columns = wide
            ? [GridItem(.flexible(), spacing: BlotterFace.space(1)), GridItem(.flexible(), spacing: BlotterFace.space(1))]
            : [GridItem(.flexible())]
        return VStack(alignment: .leading, spacing: BlotterFace.space(1)) {
            if session.exportFailed {
                exportFault
            }
            Text("Books")
                .blotterText(.caption)
                .foregroundStyle(BlotterInk.Palette.muted)
            LazyVGrid(columns: columns, alignment: .leading, spacing: BlotterFace.space(1)) {
                Button {
                    Task { await session.exportBooks() }
                } label: {
                    settingsLabel("Export CSV", symbol: "square.and.arrow.up")
                }
                .buttonStyle(BlotterPressStyle())
                .disabled(session.isBusy)
                if let url = session.exportURL {
                    ShareLink(item: url) {
                        settingsLabel("Share the books", symbol: "square.and.arrow.up.on.square")
                    }
                    .buttonStyle(.plain)
                }
                Link(destination: BlotterClient.contactURL) {
                    settingsLabel("Contact Docquet", symbol: "envelope")
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the contact page")
                Button(action: session.rerunOnboarding) {
                    settingsLabel("Re-run onboarding", symbol: "arrow.counterclockwise")
                }
                .buttonStyle(BlotterPressStyle())
                Button(role: .destructive) {
                    confirmReset = true
                } label: {
                    settingsLabel("Reset all data", symbol: "trash")
                }
                .buttonStyle(BlotterPressStyle())
                .disabled(session.isBusy)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var helpColumn: some View {
        Group {
            if !session.daybook.hasInk {
                emptyHeader
            } else {
                GeometryReader { proxy in
                    let wide = proxy.size.width >= 560
                    VStack(alignment: .leading, spacing: BlotterFace.space(1)) {
                        Text("This month on the books")
                            .blotterText(.headline)
                        Text(
                            "\(BlotterFigures.monthTitle(session.visibleMonth, calendar: calendar)) · \(session.monthMix.cashCount) cash · \(session.monthMix.tripCount) trips"
                        )
                        .blotterText(.caption)
                        .foregroundStyle(BlotterInk.Palette.muted)
                        .lineLimit(2)
                        Button(action: session.openTodayBlotter) {
                            Text("File a line")
                                .blotterText(.headline)
                                .foregroundStyle(BlotterInk.Palette.surface)
                                .frame(maxWidth: .infinity, minHeight: BlotterFace.tap)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BlotterInk.Palette.accent)
                        .disabled(session.isBusy)
                        .accessibilityHint("Opens today's blotter")
                        if wide {
                            HStack(alignment: .top, spacing: BlotterFace.space(1)) {
                                KindInkColumn(
                                    title: "Billed versus personal",
                                    figure: BlotterFigures.money(session.monthMix.billed),
                                    caption: "Personal \(BlotterFigures.money(session.monthMix.personal))",
                                    facts: BooksFact.fromProjects(session.books, jobs: session.daybook.jobs),
                                    onHeader: session.openTodayBlotter,
                                    onOpen: session.openBooksTap
                                )
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
                        } else {
                            BooksMix(
                                billed: session.monthMix.billed,
                                personal: session.monthMix.personal,
                                cashBilled: session.monthMix.cashBilled,
                                milesBilled: session.monthMix.milesBilled,
                                billedLine: "Export writes billed and personal on this device",
                                personalLine: "Nothing leaves this device until you share",
                                facts: booksFacts,
                                showsSummary: true,
                                onOpen: session.openBooksTap
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var booksFacts: [BooksFact] {
        BooksFact.fromProjects(session.books, jobs: session.daybook.jobs)
            + BooksFact.fromLines(
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

    private var exportFault: some View {
        VStack(alignment: .leading, spacing: BlotterFace.space(1)) {
            Text("Export did not finish")
                .blotterText(.headline)
            Text("The CSV stays on this device. Retry the write.")
                .blotterText(.callout)
                .foregroundStyle(BlotterInk.Palette.muted)
            Button("Retry export") { Task { await session.exportBooks() } }
                .buttonStyle(.borderedProminent)
                .tint(BlotterInk.Palette.accent)
                .disabled(session.isBusy)
                .frame(maxWidth: .infinity, minHeight: BlotterFace.tap)
        }
        .padding(BlotterFace.space(2))
        .frame(maxWidth: .infinity, alignment: .leading)
        .blotterCard()
    }

    private var emptyHeader: some View {
        VStack(spacing: BlotterFace.space(2)) {
            Image("dcq_EmptyList")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: BlotterFace.space(20))
                .padding(BlotterFace.space(2))
                .background(BlotterInk.Palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: BlotterFace.cardRadius, style: .continuous))
                .accessibilityHidden(true)
            Text("Nothing to export yet")
                .blotterText(.headline)
            Text("File a line on Expenses, then export the books from here.")
                .blotterText(.body)
                .foregroundStyle(BlotterInk.Palette.muted)
                .multilineTextAlignment(.center)
            Button {
                session.openTodayBlotter()
            } label: {
                Text("File today's line")
                    .blotterText(.headline)
                    .foregroundStyle(BlotterInk.Palette.surface)
                    .frame(maxWidth: .infinity, minHeight: BlotterFace.tap)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderedProminent)
            .tint(BlotterInk.Palette.accent)
        }
        .padding(BlotterFace.space(2))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func settingsLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: BlotterFace.space(1)) {
            Image(systemName: symbol)
                .foregroundStyle(title == "Reset all data" ? Color.red : BlotterInk.Palette.accent)
                .frame(width: BlotterFace.space(3), height: BlotterFace.tap)
                .accessibilityHidden(true)
            Text(title)
                .blotterText(.body)
                .frame(maxWidth: .infinity, minHeight: BlotterFace.tap, alignment: .leading)
        }
        .padding(.horizontal, BlotterFace.space(2))
        .frame(maxWidth: .infinity, minHeight: BlotterFace.tap, alignment: .leading)
        .contentShape(Rectangle())
        .blotterCard()
    }
}
