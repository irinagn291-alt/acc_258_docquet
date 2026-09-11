import Foundation

/// Role: Chain. Tab chrome. Expenses holds the month grid and fused blotter; Balance and Settings are siblings. No Game tab.
enum BlotterTab: String, Hashable, Sendable, CaseIterable {
    case expenses
    case balance
    case settings
}

/// Role: Chain. Launch keys for live shots. today, log, and goals open three different screens.
enum ReviewPane: String, Equatable, Sendable {
    case today
    case log
    case goals

    var tab: BlotterTab {
        switch self {
        case .today: .expenses
        case .log: .balance
        case .goals: .settings
        }
    }
}

/// Role: Chain. Reads `-ReviewScreen today|log|goals` once, only after onboarding. Never hosts a View.
enum BlotterLaunch {
    static func peek(arguments: [String] = ProcessInfo.processInfo.arguments) -> ReviewPane? {
        guard let index = arguments.firstIndex(of: "-ReviewScreen") else { return nil }
        let next = arguments.index(after: index)
        guard arguments.indices.contains(next) else { return nil }
        return ReviewPane(rawValue: arguments[next])
    }

    static func consume(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        onboardingComplete: Bool,
        consumed: inout Bool
    ) -> ReviewPane? {
        guard onboardingComplete, !consumed else { return nil }
        consumed = true
        return peek(arguments: arguments)
    }
}
