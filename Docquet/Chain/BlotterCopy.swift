import Foundation

/// Role: Chain. User-facing blotter copy. Never names types, files, or UserDefaults.
enum BlotterCopy {
    static func fault(_ fault: BlotterFault) -> String {
        switch fault {
        case .unknownJob:
            "Pick a project before filing."
        case .invalidAmount:
            "Enter an amount greater than zero."
        case .invalidMiles:
            "Enter a valid odometer reading."
        case .endBelowStart:
            "End miles cannot sit below the start reading."
        case .emptyName:
            "Name the project."
        case .invalidRate:
            "Enter a mileage rate of zero or more."
        }
    }

    static func warning(_ warning: DaybookWarning) -> String {
        switch warning {
        case .recoveredFromBackup:
            "Restored the last good daybook."
        case .startedEmpty:
            "The saved daybook could not be read."
        }
    }
}
