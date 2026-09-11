import SwiftUI

/// Role: Chain. Blotter-tab chrome. Expenses holds the month grid and fused blotter; Balance and Settings are siblings.
struct BlotterChrome: View {
    @ObservedObject var session: DaybookSession
    var calendar: Calendar
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $session.selectedTab) {
            NavigationStack {
                ExpensesPane(session: session, calendar: calendar)
            }
            .tabItem {
                Label("Expenses", systemImage: "calendar")
            }
            .tag(BlotterTab.expenses)

            NavigationStack {
                BalancePane(session: session, calendar: calendar)
            }
            .tabItem {
                Label("Balance", systemImage: "books.vertical")
            }
            .tag(BlotterTab.balance)

            NavigationStack {
                SettingsPane(session: session, calendar: calendar)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(BlotterTab.settings)
        }
        .tint(BlotterInk.Palette.accent)
        .toolbarBackground(BlotterInk.Palette.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .fullScreenCover(isPresented: $session.showOnboarding) {
            OnboardingWalk {
                Task { await session.finishOnboarding() }
            }
        }
        .sheet(isPresented: $session.showChain) {
            OdometerPane(session: session)
        }
        .overlay {
            if session.showSpinner {
                ProgressView()
                    .tint(BlotterInk.Palette.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(BlotterInk.Palette.background.opacity(0.55))
                    .accessibilityLabel("Loading the daybook")
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                session.noteBecameActive()
            }
            if phase == .inactive || phase == .background {
                Task { await session.flush() }
            }
        }
        .preferredColorScheme(.light)
        .blotterScreen()
    }
}
