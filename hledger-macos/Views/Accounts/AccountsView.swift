/// Accounts view with flat/tree toggle, locale-formatted balances, and search.

import SwiftUI

struct AccountsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewMode = "flat"
    @State private var treeNodes: [AccountNode] = []
    @State private var searchText = ""
    @State private var isLoading = false

    private var filteredBalances: [AccountBalance] {
        let parsed = appState.accountBalances.map { AccountBalance(account: $0.0, rawBalance: $0.1) }
        guard !searchText.isEmpty else { return parsed }
        let query = searchText.lowercased()
        return parsed.filter { $0.account.lowercased().contains(query) }
    }

    private var filteredTree: [AccountNode] {
        guard !searchText.isEmpty else { return treeNodes }
        let query = searchText.lowercased()
        return treeNodes.filter { filterNode($0, query: query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView("Loading accounts...")
                Spacer()
            } else if viewMode == "flat" {
                flatView
            } else {
                treeView
            }
        }
        .searchable(text: $searchText, prompt: "Filter accounts...")
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("View", selection: $viewMode) {
                    Text("Flat").tag("flat")
                    Text("Tree").tag("tree")
                }
                .pickerStyle(.segmented)
            }
        }
        .task { await loadData() }
        .onChange(of: viewMode) { Task { await loadData() } }
    }

    // MARK: - Flat View

    private var flatView: some View {
        Group {
            if filteredBalances.isEmpty {
                ContentUnavailableView("No Accounts", systemImage: "building.columns",
                    description: Text(searchText.isEmpty ? "No accounts found in journal." : "No matching accounts."))
            } else {
                List {
                    ForEach(filteredBalances) { row in
                        AccountRow(
                            label: row.account,
                            value: row.formattedBalance,
                            valueColor: row.balanceColor
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Tree View

    private var treeView: some View {
        Group {
            if filteredTree.isEmpty {
                ContentUnavailableView("No Accounts", systemImage: "building.columns",
                    description: Text(searchText.isEmpty ? "No accounts found in journal." : "No matching accounts."))
            } else {
                List {
                    OutlineGroup(filteredTree, children: \.optionalChildren) { node in
                        AccountRow(
                            label: node.name,
                            value: formatNodeBalance(node.balance),
                            valueColor: nodeBalanceColor(node.balance)
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard let backend = appState.activeBackend else { return }
        isLoading = true
        do {
            if viewMode == "flat" {
                appState.accountBalances = try await backend.loadAccountBalances()
            } else {
                treeNodes = try await backend.loadAccountTreeBalances()
            }
        } catch {
            appState.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func filterNode(_ node: AccountNode, query: String) -> Bool {
        if node.fullPath.lowercased().contains(query) { return true }
        return node.children.contains { filterNode($0, query: query) }
    }

    // MARK: - Tree Balance Formatting

    private func formatNodeBalance(_ raw: String) -> String {
        let (qty, commodity) = AmountParser.parse(raw)
        if qty == 0 && commodity.isEmpty { return raw }
        return AmountFormatter.format(qty, commodity: commodity)
    }

    private func nodeBalanceColor(_ raw: String) -> Color {
        let (qty, _) = AmountParser.parse(raw)
        return qty < 0 ? .red : .secondary
    }
}

// MARK: - Account Balance Row

struct AccountBalance: Identifiable {
    let id = UUID()
    let account: String
    let rawBalance: String

    var parsedAmount: Decimal {
        AmountParser.parse(rawBalance).0
    }

    var parsedCommodity: String {
        AmountParser.parse(rawBalance).1
    }

    var formattedBalance: String {
        let (qty, commodity) = AmountParser.parse(rawBalance)
        if qty == 0 && commodity.isEmpty { return rawBalance }
        return AmountFormatter.format(qty, commodity: commodity)
    }

    var balanceColor: Color {
        parsedAmount < 0 ? .red : .primary
    }
}
