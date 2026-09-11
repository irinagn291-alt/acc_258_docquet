import SwiftUI

/// Role: Chain. One labeled books fact. A Button when it opens a day, cash, miles, or a project.
struct BooksFact: Identifiable, Equatable {
    var id: String
    var title: String
    var figure: String
    var line: String
    var tap: BooksTap
}

/// Role: Chain. Billed versus personal, cash versus miles, and filed lines as ink. Occupies remaining height with rows, not leftover color.
struct BooksMix: View {
    var billed: Double
    var personal: Double
    var cashBilled: Double
    var milesBilled: Double
    var billedLine: String
    var personalLine: String
    var facts: [BooksFact]
    var showsSummary: Bool = true
    var onOpen: (BooksTap) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BlotterFace.space(1)) {
            if showsSummary {
                summary
            }
            InkFill(items: facts) { fact in
                BooksFactButton(fact: fact) {
                    onOpen(fact.tap)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Billed \(BlotterFigures.money(billed)), personal \(BlotterFigures.money(personal))"
        )
    }

    private var summary: some View {
        VStack(spacing: BlotterFace.space(1)) {
            HStack(spacing: BlotterFace.space(1)) {
                Button {
                    onOpen(.cash)
                } label: {
                    summaryLabel(
                        title: "Billed",
                        figure: BlotterFigures.money(billed),
                        line: billedLine
                    )
                }
                .buttonStyle(BlotterPressStyle())
                .accessibilityLabel("Billed \(BlotterFigures.money(billed))")
                .accessibilityHint("Opens today's blotter on cash")
                Button {
                    onOpen(.cash)
                } label: {
                    summaryLabel(
                        title: "Personal",
                        figure: BlotterFigures.money(personal),
                        line: personalLine
                    )
                }
                .buttonStyle(BlotterPressStyle())
                .accessibilityLabel("Personal \(BlotterFigures.money(personal))")
                .accessibilityHint("Opens today's blotter")
            }
            HStack(spacing: BlotterFace.space(1)) {
                Button {
                    onOpen(.cash)
                } label: {
                    summaryLabel(
                        title: "Cash billed",
                        figure: BlotterFigures.money(cashBilled),
                        line: "File cash"
                    )
                }
                .buttonStyle(BlotterPressStyle())
                .accessibilityLabel("Cash billed \(BlotterFigures.money(cashBilled))")
                .accessibilityHint("Opens today's blotter on cash")
                Button {
                    onOpen(.miles)
                } label: {
                    summaryLabel(
                        title: "Miles billed",
                        figure: BlotterFigures.money(milesBilled),
                        line: "File miles"
                    )
                }
                .buttonStyle(BlotterPressStyle())
                .accessibilityLabel("Miles billed \(BlotterFigures.money(milesBilled))")
                .accessibilityHint("Opens today's blotter on miles")
            }
        }
    }

    private func summaryLabel(title: String, figure: String, line: String) -> some View {
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
                .lineLimit(1)
        }
        .padding(BlotterFace.space(1))
        .frame(maxWidth: .infinity, minHeight: BlotterFace.tap, alignment: .leading)
        .contentShape(Rectangle())
        .blotterCard()
    }
}

/// Role: Chain. Cash or miles column filled with filed lines, not a stretched empty card.
struct KindInkColumn: View {
    var title: String
    var figure: String
    var caption: String
    var facts: [BooksFact]
    var onHeader: () -> Void
    var onOpen: (BooksTap) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BlotterFace.space(1)) {
            Button(action: onHeader) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .blotterText(.caption)
                        .foregroundStyle(BlotterInk.Palette.muted)
                        .lineLimit(1)
                    Text(figure)
                        .blotterText(.figure)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(caption)
                        .blotterText(.caption)
                        .foregroundStyle(BlotterInk.Palette.muted)
                        .lineLimit(2)
                }
                .padding(BlotterFace.space(1))
                .frame(maxWidth: .infinity, minHeight: BlotterFace.tap, alignment: .leading)
                .contentShape(Rectangle())
                .blotterHeroCard()
            }
            .buttonStyle(BlotterPressStyle())
            .accessibilityLabel("\(title) \(figure)")
            .accessibilityHint(caption)
            Group {
                if facts.isEmpty {
                    Button(action: onHeader) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Nothing filed yet")
                                .blotterText(.headline)
                                .lineLimit(2)
                            Text(caption)
                                .blotterText(.callout)
                                .foregroundStyle(BlotterInk.Palette.muted)
                                .lineLimit(3)
                        }
                        .padding(BlotterFace.space(2))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .contentShape(Rectangle())
                        .blotterCard()
                    }
                    .buttonStyle(BlotterPressStyle())
                    .accessibilityLabel("Nothing filed yet. \(caption)")
                } else {
                    InkFill(items: facts) { fact in
                        BooksFactButton(fact: fact) {
                            onOpen(fact.tap)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// Role: Chain. Shares remaining height across books rows. Scrolls only when rows cannot keep a 44pt hit.
struct InkFill<Item: Identifiable, Content: View>: View {
    var items: [Item]
    var content: (Item) -> Content

    var body: some View {
        GeometryReader { proxy in
            let needed = BlotterFace.tap * CGFloat(max(items.count, 1))
                + BlotterFace.space(1) * CGFloat(max(items.count - 1, 0))
            if items.isEmpty {
                Text("Nothing filed on these books yet.")
                    .blotterText(.callout)
                    .foregroundStyle(BlotterInk.Palette.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if needed > proxy.size.height {
                ScrollView {
                    VStack(spacing: BlotterFace.space(1)) {
                        ForEach(items) { item in
                            content(item)
                                .frame(minHeight: BlotterFace.tap)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .contentMargins(.bottom, BlotterFace.space(1), for: .scrollContent)
            } else {
                VStack(spacing: BlotterFace.space(1)) {
                    ForEach(items) { item in
                        content(item)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: BlotterFace.tap,
                                maxHeight: .infinity,
                                alignment: .leading
                            )
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
        }
    }
}

/// Role: Chain. One books row as a Button. Chrome lives in the label.
struct BooksFactButton: View {
    var fact: BooksFact
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Text(fact.title)
                    .blotterText(.headline)
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: BlotterFace.space(1)) {
                    Text(fact.line)
                        .blotterText(.caption)
                        .foregroundStyle(BlotterInk.Palette.muted)
                        .lineLimit(2)
                    Spacer(minLength: BlotterFace.space(1))
                    Text(fact.figure)
                        .blotterText(.figure)
                        .layoutPriority(1)
                }
            }
            .padding(.horizontal, BlotterFace.space(2))
            .padding(.vertical, BlotterFace.space(1))
            .frame(maxWidth: .infinity, minHeight: BlotterFace.tap, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .blotterCard()
        }
        .buttonStyle(BlotterPressStyle())
        .accessibilityLabel("\(fact.title), \(fact.figure), \(fact.line)")
        .accessibilityHint("Opens the blotter")
        .accessibilityAddTraits(.isButton)
    }
}

extension BooksFact {
    static func fromLines(
        _ lines: [BlotterInkLine],
        jobs: [Job],
        calendar: Calendar,
        showDay: Bool
    ) -> [BooksFact] {
        let explode = lines.count <= 4
        return lines.flatMap { line in
            facts(for: line, jobs: jobs, calendar: calendar, showDay: showDay, explode: explode)
        }
    }

    static func fromProjects(_ books: [JobBooks], jobs: [Job]) -> [BooksFact] {
        books.map { book in
            let name = jobs.first { $0.id == book.jobID }?.name ?? "Project"
            return BooksFact(
                id: "job-\(book.jobID.uuidString)",
                title: name,
                figure: BlotterFigures.money(book.billed),
                line: "Billed \(BlotterFigures.money(book.billed)) · Personal \(BlotterFigures.money(book.personal)) · Cash \(BlotterFigures.money(book.cashBilled)) · Miles \(BlotterFigures.money(book.milesBilled))",
                tap: .job(book.jobID)
            )
        }
    }

    private static func facts(
        for line: BlotterInkLine,
        jobs: [Job],
        calendar: Calendar,
        showDay: Bool,
        explode: Bool
    ) -> [BooksFact] {
        let name = jobs.first { $0.id == line.jobID }?.name ?? "Project"
        let split: String
        switch (line.kind, line.isBillable) {
        case (.cash, true): split = "Billable cash"
        case (.cash, false): split = "Personal cash"
        case (.miles, true): split = "Billable miles"
        case (.miles, false): split = "Personal miles"
        }
        let dayPrefix = showDay ? "\(BlotterFigures.dayTitle(line.daykey, calendar: calendar)) · " : ""
        let fold = BlotterFigures.money(line.isBillable ? line.billed : line.personal)
        let figure: String
        if line.kind == .miles, let distance = line.distance {
            figure = "\(BlotterFigures.miles(distance)) · \(fold)"
        } else {
            figure = fold
        }
        var rows = [
            BooksFact(
                id: line.id.uuidString,
                title: name,
                figure: figure,
                line: "\(dayPrefix)\(split)",
                tap: .day(line.daykey)
            ),
        ]
        if explode, line.kind == .miles, let start = line.startMiles, let end = line.endMiles {
            let rate = line.ratePerMile.map { BlotterFigures.rate($0) } ?? ""
            rows.append(
                BooksFact(
                    id: "\(line.id.uuidString)-chain",
                    title: "Start to end",
                    figure: "\(BlotterFigures.miles(start)) → \(BlotterFigures.miles(end))",
                    line: rate.isEmpty ? "Miles on the chain" : "Miles at \(rate)",
                    tap: .day(line.daykey)
                )
            )
        }
        if explode {
            rows.append(
                BooksFact(
                    id: "\(line.id.uuidString)-fold",
                    title: line.isBillable ? "Folds into billed" : "Off billed",
                    figure: fold,
                    line: line.kind == .cash ? "Cash on the books" : "Miles on the chain",
                    tap: .day(line.daykey)
                )
            )
        }
        return rows
    }
}
