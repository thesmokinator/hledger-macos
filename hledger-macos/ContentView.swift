/// Main content view with NavigationSplitView: sidebar + detail.

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var aiAssistant = AIAssistant()
    @State private var showingAIChat = false

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            detailView
        }
        .overlay(alignment: .bottomLeading) {
            if appState.config.aiEnabled {
                AIToggleButton(isShowingChat: $showingAIChat, isAvailable: aiAssistant.isAvailable)
                    .padding(Theme.Spacing.lg)
            }
        }
        .overlay(alignment: .trailing) {
            if appState.config.aiEnabled && showingAIChat {
                AIChatOverlay(assistant: aiAssistant, isShowing: $showingAIChat)
                    .padding(.vertical, Theme.Spacing.sm)
                    .padding(.trailing, Theme.Spacing.sm)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleAIChat)) { _ in
            toggleAIChat()
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

    /// Toggle the AI chat panel (called from keyboard shortcut).
    func toggleAIChat() {
        guard appState.config.aiEnabled else { return }
        withAnimation(.spring(duration: 0.3)) {
            showingAIChat.toggle()
        }
    }
}
