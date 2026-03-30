/// Main content view with NavigationSplitView: sidebar + detail.

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            detailView
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.selectedSection {
        case .summary:
            SummaryView()
        case .transactions:
            TransactionsView()
        case .recurring:
            RecurringView()
        case .budget:
            BudgetView()
        case .reports:
            ReportsView()
        case .accounts:
            AccountsView()
        }
    }
}
