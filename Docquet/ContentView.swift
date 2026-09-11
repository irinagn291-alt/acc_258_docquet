import SwiftUI

/// Role: Chain. Root. Observes DaybookSession; never writes lastEndMiles or UserDefaults.
struct ContentView: View {
    @StateObject private var session: DaybookSession
    var calendar: Calendar

    init() {
        let store: any DaybookStoring
        if let directory = try? DaybookStore.applicationSupportDirectory() {
            store = DaybookStore(directory: directory)
        } else {
            store = DaybookHold()
        }
        _session = StateObject(wrappedValue: DaybookSession(store: store))
        calendar = .current
    }

    init(session: DaybookSession, calendar: Calendar = .current) {
        _session = StateObject(wrappedValue: session)
        self.calendar = calendar
    }

    var body: some View {
        BlotterChrome(session: session, calendar: calendar)
            .task {
                await session.bootstrap()
            }
    }
}

#Preview {
    ContentView(
        session: DaybookSession(
            store: DaybookHold(daybook: (try? DaybookSeed.daybook()) ?? .empty)
        )
    )
}
