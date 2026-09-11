import SwiftUI

/// Role: Chain. Calendar-first month. Every day is a 44pt grid button that expands the inline blotter.
struct MonthBoard: View {
    var cells: [MonthCell]
    var selected: Daykey?
    var calendar: Calendar
    var onSelect: (MonthCell) -> Void

    var body: some View {
        let weeks = MonthLattice.weeks(cells)
        let letters = BlotterFigures.weekdayLetters(calendar: calendar)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(letters.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .blotterText(.caption)
                        .foregroundStyle(BlotterInk.Palette.muted)
                        .frame(maxWidth: .infinity, minHeight: BlotterFace.space(3))
                        .accessibilityHidden(true)
                }
            }
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(0 ..< 7, id: \.self) { column in
                        if week.indices.contains(column), let cell = week[column] {
                            Button {
                                onSelect(cell)
                            } label: {
                                dayCell(cell)
                            }
                            .buttonStyle(BlotterPressStyle())
                            .disabled(cell.isFuture)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .accessibilityLabel(label(cell))
                            .accessibilityHint(cell.isFuture ? "Still ahead" : "Opens the blotter for this day")
                            .accessibilityAddTraits(traits(cell))
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dcq.month")
    }

    private func dayCell(_ cell: MonthCell) -> some View {
        let selected = selected == cell.daykey
        return VStack(spacing: 0) {
            Text(BlotterFigures.dayNumber(cell.daykey.day))
                .font(BlotterFace.Step.figure.font)
                .foregroundStyle(cell.isFuture ? BlotterInk.Palette.muted : BlotterInk.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(mark(cell))
                .blotterText(.caption)
                .foregroundStyle(BlotterInk.Palette.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: BlotterFace.tap, maxHeight: .infinity)
        .background(fill(cell, selected: selected))
        .clipShape(RoundedRectangle(cornerRadius: BlotterFace.chipRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BlotterFace.chipRadius, style: .continuous)
                .stroke(
                    selected || cell.isToday ? BlotterInk.Palette.accent : BlotterInk.Palette.muted.opacity(0.35),
                    lineWidth: BlotterFace.hairline
                )
        }
        .contentShape(Rectangle())
        .opacity(cell.isFuture ? 0.45 : 1)
    }

    private func fill(_ cell: MonthCell, selected: Bool) -> Color {
        if selected {
            return BlotterInk.Palette.accent.opacity(0.16)
        }
        if cell.billable > 0 {
            return BlotterInk.Palette.accent.opacity(0.10)
        }
        return BlotterInk.Palette.surface
    }

    private func mark(_ cell: MonthCell) -> String {
        if cell.billable > 0 {
            return BlotterFigures.compactMoney(cell.billable)
        }
        if cell.hasInk {
            return "Personal"
        }
        if cell.isToday {
            return "Today"
        }
        return cell.isFuture ? "—" : "Open"
    }

    private func label(_ cell: MonthCell) -> String {
        var parts = [BlotterFigures.dayTitle(cell.daykey, calendar: calendar)]
        if cell.isToday { parts.append("today") }
        if cell.billable > 0 {
            parts.append("billed \(BlotterFigures.money(cell.billable))")
        } else if cell.hasInk {
            parts.append("personal ink")
        } else if cell.isFuture {
            parts.append("ahead")
        } else {
            parts.append("open")
        }
        return parts.joined(separator: ", ")
    }

    private func traits(_ cell: MonthCell) -> AccessibilityTraits {
        if selected == cell.daykey || cell.isToday {
            return .isSelected
        }
        return []
    }
}
