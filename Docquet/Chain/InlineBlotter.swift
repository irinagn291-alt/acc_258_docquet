import SwiftUI

/// Role: Chain. Fused inline blotter. Cash or miles, a full project, amount or end miles, billable or personal, and File sit on one surface. Creating a Job stays here. Never a pushed form.
struct InlineBlotter: View {
    enum Field: Hashable {
        case amount
        case endMiles
        case jobName
        case jobRate
        case jobStart
    }

    @ObservedObject var session: DaybookSession
    var compact: Bool
    @FocusState private var focused: Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: BlotterFace.space(1)) {
            Group {
                header
                kindRow
                if session.daybook.hasJobs {
                    JobPicker(session: session, compact: compact)
                }
                if session.showJobDraft || !session.daybook.hasJobs {
                    ScrollView {
                        JobDraft(session: session, focused: $focused)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .frame(maxHeight: BlotterFace.space(28))
                }
                inkFields
                billableRow
                if let fault = session.fault {
                    Text(BlotterCopy.fault(fault))
                        .blotterText(.callout)
                        .foregroundStyle(BlotterInk.Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            .layoutPriority(1)
            filedReadout
            filingWorkspace
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(0)
            fileButton
                .layoutPriority(2)
        }
        .padding(compact ? BlotterFace.space(1) : BlotterFace.space(2))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .blotterCard()
        .padding(.horizontal, BlotterFace.space(1))
        .padding(.bottom, BlotterFace.space(1))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = nil }
                    .accessibilityLabel("Done")
            }
        }
        .animation(BlotterMotion.fade(reduceMotion), value: session.kind)
        .onChange(of: session.amountText) { _, _ in
            session.rejectNegativeDrafts()
        }
        .onChange(of: session.endMilesText) { _, _ in
            session.rejectNegativeDrafts()
        }
        .onChange(of: session.jobRateText) { _, _ in
            session.rejectNegativeDrafts()
        }
        .onChange(of: session.jobStartText) { _, _ in
            session.rejectNegativeDrafts()
        }
        .overlay(alignment: .topTrailing) {
            if session.filedPulse {
                Image("dcq_SuccessMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: BlotterFace.space(6), height: BlotterFace.space(6))
                    .padding(BlotterFace.space(1))
                    .accessibilityLabel("Line filed")
                    .onAppear {
                        Task {
                            try? await Task.sleep(nanoseconds: 800_000_000)
                            session.clearPulse()
                        }
                    }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let day = session.selectedDay {
                Text(BlotterFigures.dayTitle(day, calendar: .current))
                    .blotterText(.headline)
            }
            Text(session.nextTapCopy)
                .blotterText(.callout)
                .foregroundStyle(BlotterInk.Palette.muted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var kindRow: some View {
        HStack(spacing: BlotterFace.space(1)) {
            kindChip(.cash)
            kindChip(.miles)
        }
    }

    private func kindChip(_ kind: DaybookSession.InkKind) -> some View {
        Button {
            focused = nil
            session.selectKind(kind)
        } label: {
            Text(kind.title)
                .blotterText(.headline)
                .frame(maxWidth: .infinity, minHeight: BlotterFace.tap)
                .contentShape(Rectangle())
                .blotterChip(selected: session.kind == kind)
        }
        .buttonStyle(BlotterPressStyle())
        .accessibilityAddTraits(session.kind == kind ? .isSelected : [])
    }

    @ViewBuilder
    private var inkFields: some View {
        if session.kind == .miles {
            if !compact, let job = session.selectedJob {
                ChainRead(job: job, onOpen: session.openChain)
            }
            milesFields
        } else {
            cashField
        }
    }

    private var cashField: some View {
        HStack(spacing: BlotterFace.space(1)) {
            Text("Amount")
                .blotterText(.caption)
                .foregroundStyle(BlotterInk.Palette.muted)
            TextField("0", text: $session.amountText)
                .blotterText(.figure)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($focused, equals: .amount)
                .accessibilityLabel("Amount")
        }
        .padding(.horizontal, BlotterFace.space(1))
        .frame(maxWidth: .infinity, minHeight: BlotterFace.tap)
        .blotterCard()
    }

    private var milesFields: some View {
        VStack(alignment: .leading, spacing: BlotterFace.space(1)) {
            HStack(spacing: BlotterFace.space(1)) {
                Button(action: session.openChain) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Start")
                            .blotterText(.caption)
                            .foregroundStyle(BlotterInk.Palette.muted)
                        Text(BlotterFigures.miles(session.startMiles))
                            .blotterText(.figure)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, BlotterFace.space(1))
                    .frame(maxWidth: .infinity, minHeight: BlotterFace.tap, alignment: .leading)
                    .contentShape(Rectangle())
                    .blotterCard()
                }
                .buttonStyle(BlotterPressStyle())
                .accessibilityLabel("Start miles \(BlotterFigures.miles(session.startMiles))")
                .accessibilityHint("Opens the mileage chain")
                VStack(alignment: .leading, spacing: 0) {
                    Text("End odometer")
                        .blotterText(.caption)
                        .foregroundStyle(BlotterInk.Palette.muted)
                    TextField("End miles", text: $session.endMilesText)
                        .blotterText(.figure)
                        .keyboardType(.decimalPad)
                        .focused($focused, equals: .endMiles)
                        .accessibilityLabel("End odometer")
                }
                .padding(.horizontal, BlotterFace.space(1))
                .frame(maxWidth: .infinity, minHeight: BlotterFace.tap, alignment: .leading)
                .blotterCard()
            }
            if let end = BlotterFigures.parse(session.endMilesText) {
                let distance = (try? OdometerChain.distance(startMiles: session.startMiles, endMiles: end)) ?? -1
                if distance >= 0 {
                    Text("Distance \(BlotterFigures.miles(distance))")
                        .blotterText(.callout)
                        .foregroundStyle(BlotterInk.Palette.muted)
                }
            }
        }
    }

    private var billableRow: some View {
        HStack(spacing: BlotterFace.space(1)) {
            billableChip(true, title: "Billable")
            billableChip(false, title: "Personal")
        }
    }

    private func billableChip(_ value: Bool, title: String) -> some View {
        Button {
            session.isBillable = value
        } label: {
            Text(title)
                .blotterText(.headline)
                .frame(maxWidth: .infinity, minHeight: BlotterFace.tap)
                .contentShape(Rectangle())
                .blotterChip(selected: session.isBillable == value)
        }
        .buttonStyle(BlotterPressStyle())
        .accessibilityAddTraits(session.isBillable == value ? .isSelected : [])
    }

    @ViewBuilder
    private var filedReadout: some View {
        if compact {
            let outlays = session.selectedOutlays
            let trips = session.selectedTrips
            VStack(alignment: .leading, spacing: 0) {
                Text("Filed on this day")
                    .blotterText(.caption)
                    .foregroundStyle(BlotterInk.Palette.muted)
                if outlays.isEmpty && trips.isEmpty {
                    Text("Nothing filed on this day yet.")
                        .blotterText(.callout)
                        .foregroundStyle(BlotterInk.Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(compactFiledLine(outlays: outlays, trips: trips))
                        .blotterText(.callout)
                        .foregroundStyle(BlotterInk.Palette.ink)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    private var filingWorkspace: some View {
        VStack(alignment: .leading, spacing: BlotterFace.space(1)) {
            if compact {
                daySplitStrip
            } else {
                if let ready = session.draftReady {
                    thisLineCard(ready)
                }
                HStack(alignment: .top, spacing: BlotterFace.space(1)) {
                    KindInkColumn(
                        title: "Cash on this day",
                        figure: BlotterFigures.money(
                            (session.selectedDayBook?.cashBilled ?? 0) + (session.selectedDayBook?.cashPersonal ?? 0)
                        ),
                        caption: "File cash for \(session.selectedJob?.name ?? "a project")",
                        facts: dayCashFacts,
                        onHeader: {
                            session.selectKind(.cash)
                        },
                        onOpen: session.openBooksTap
                    )
                    KindInkColumn(
                        title: "Miles on this day",
                        figure: BlotterFigures.money(
                            (session.selectedDayBook?.milesBilled ?? 0) + (session.selectedDayBook?.milesPersonal ?? 0)
                        ),
                        caption: "File miles on the chain",
                        facts: dayMilesFacts,
                        onHeader: {
                            session.selectKind(.miles)
                        },
                        onOpen: session.openBooksTap
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var dayCashFacts: [BooksFact] {
        var facts: [BooksFact] = []
        if let day = session.selectedDayBook, let selected = session.selectedDay {
            facts.append(
                BooksFact(
                    id: "cash-split-\(selected.rawValue)",
                    title: "Cash billed",
                    figure: BlotterFigures.money(day.cashBilled),
                    line: "Personal cash \(BlotterFigures.money(day.cashPersonal)) · File cash",
                    tap: .day(selected)
                )
            )
        }
        facts.append(
            contentsOf: BooksFact.fromLines(
                session.selectedInkLines.filter { $0.kind == .cash },
                jobs: session.daybook.jobs,
                calendar: .current,
                showDay: false
            )
        )
        return facts
    }

    private var dayMilesFacts: [BooksFact] {
        var facts: [BooksFact] = []
        if let day = session.selectedDayBook, let selected = session.selectedDay {
            facts.append(
                BooksFact(
                    id: "miles-split-\(selected.rawValue)",
                    title: "Miles billed",
                    figure: BlotterFigures.money(day.milesBilled),
                    line: "Personal miles \(BlotterFigures.money(day.milesPersonal)) · File miles",
                    tap: .day(selected)
                )
            )
        }
        facts.append(
            contentsOf: BooksFact.fromLines(
                session.selectedInkLines.filter { $0.kind == .miles },
                jobs: session.daybook.jobs,
                calendar: .current,
                showDay: false
            )
        )
        return facts
    }

    private func thisLineCard(_ ready: DraftReady) -> some View {
        Button {
            focused = nil
            Task { await session.fileDraft() }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("This line")
                    .blotterText(.caption)
                    .foregroundStyle(BlotterInk.Palette.muted)
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: BlotterFace.space(1)) {
                    Text(ready.title)
                        .blotterText(.headline)
                        .lineLimit(2)
                    Spacer(minLength: BlotterFace.space(1))
                    Text(ready.figure)
                        .blotterText(.figure)
                        .layoutPriority(1)
                }
                Text(ready.consequence)
                    .blotterText(.callout)
                    .foregroundStyle(BlotterInk.Palette.ink)
                    .lineLimit(2)
                    .padding(.top, 2)
                Text(ready.chainLine)
                    .blotterText(.caption)
                    .foregroundStyle(BlotterInk.Palette.muted)
                    .lineLimit(2)
            }
            .padding(BlotterFace.space(2))
            .frame(maxWidth: .infinity, minHeight: BlotterFace.tap, alignment: .leading)
            .contentShape(Rectangle())
            .blotterHeroCard()
        }
        .buttonStyle(BlotterPressStyle())
        .disabled(!session.canFileDraft)
        .accessibilityLabel("File \(ready.title), \(ready.figure)")
        .accessibilityHint(ready.consequence)
        .accessibilityValue(session.canFileDraft ? "Ready" : "Needs a valid line")
    }

    private var daySplitStrip: some View {
        let day = session.selectedDayBook
        return HStack(spacing: BlotterFace.space(1)) {
            VStack(alignment: .leading, spacing: 0) {
                Text("This day billed")
                    .blotterText(.caption)
                    .foregroundStyle(BlotterInk.Palette.muted)
                    .lineLimit(1)
                Text(BlotterFigures.money(day?.billed ?? 0))
                    .blotterText(.figure)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(BlotterFace.space(1))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(BlotterInk.Palette.accent.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: BlotterFace.chipRadius, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text("This day personal")
                    .blotterText(.caption)
                    .foregroundStyle(BlotterInk.Palette.muted)
                    .lineLimit(1)
                Text(BlotterFigures.money(day?.personal ?? 0))
                    .blotterText(.figure)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(BlotterFace.space(1))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(BlotterInk.Palette.muted.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: BlotterFace.chipRadius, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "This day billed \(BlotterFigures.money(day?.billed ?? 0)), personal \(BlotterFigures.money(day?.personal ?? 0))"
        )
    }

    private func compactFiledLine(outlays: [Outlay], trips: [Trip]) -> String {
        var parts: [String] = []
        for outlay in outlays {
            let name = session.daybook.job(id: outlay.jobID)?.name ?? "Project"
            let split = outlay.isBillable ? "billable cash" : "personal cash"
            parts.append("\(name) \(BlotterFigures.money(outlay.amount)) \(split)")
        }
        for trip in trips {
            let name = session.daybook.job(id: trip.jobID)?.name ?? "Project"
            let split = trip.isBillable ? "billable miles" : "personal miles"
            parts.append("\(name) \(BlotterFigures.miles(trip.distance)) \(split)")
        }
        return parts.joined(separator: " · ")
    }

    private var fileButton: some View {
        Button {
            focused = nil
            Task { await session.fileDraft() }
        } label: {
            HStack(spacing: BlotterFace.space(1)) {
                Image("dcq_ControlFace")
                    .resizable()
                    .scaledToFit()
                    .frame(width: BlotterFace.space(4), height: BlotterFace.space(4))
                    .accessibilityHidden(true)
                Text("File")
                    .blotterText(.headline)
                    .foregroundStyle(BlotterInk.Palette.surface)
            }
            .frame(maxWidth: .infinity, minHeight: BlotterFace.tap)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderedProminent)
        .tint(BlotterInk.Palette.accent)
        .controlSize(.large)
        .disabled(!session.canFileDraft)
        .opacity(session.canFileDraft ? 1 : 0.45)
        .accessibilityLabel("File")
        .accessibilityHint(session.nextTapCopy)
        .accessibilityValue(session.canFileDraft ? "Ready" : "Needs a valid line")
    }
}
