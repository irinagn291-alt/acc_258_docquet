import SwiftUI

/// Role: Chain. SF Pro via Font.system only. Six Dynamic Type steps, 8pt spacing, 12/8 radii, hairline+fill.
enum BlotterFace {
    static let face = BlotterInk.face
    static let unit: CGFloat = 8
    static let tap: CGFloat = 44
    static let cardRadius: CGFloat = 12
    static let chipRadius: CGFloat = 8
    static let hairline: CGFloat = 1

    static func space(_ steps: Int) -> CGFloat {
        unit * CGFloat(steps)
    }

    /// Six SF Pro steps. Display is the month title. Figure is amounts, miles, rates, and month totals.
    enum Step: CaseIterable {
        case display
        case headline
        case body
        case figure
        case callout
        case caption

        var font: Font {
            switch self {
            case .display:
                .system(.title).weight(.semibold)
            case .headline:
                .system(.headline)
            case .body:
                .system(.body)
            case .figure:
                .system(.title3).weight(.semibold).monospacedDigit()
            case .callout:
                .system(.callout)
            case .caption:
                .system(.footnote)
            }
        }
    }
}
