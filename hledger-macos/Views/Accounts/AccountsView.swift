/// Accounts view with flat/tree toggle, locale-formatted balances, and search.

import SwiftUI

struct AccountsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewMode = "flat"
    @State private var sortAscending = true
    @State private var treeNodes: [AccountNode] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var drillDown: AccountDrillDown?

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
                Button { Task { await appState.reload() } } label: {
                    Label("Reload", systemImage: "arrow.triangle.2.circlepath")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Picker("View", selection: $viewMode) {
                    Text("Flat").tag("flat")
                    Text("Tree").tag("tree")
                }
                .pickerStyle(.segmented)
            }
        }
        .sheet(item: $drillDown) { item in
            AccountTransactionsSheet(accountName: item.accountName)
                .environment(appState)
        }
        .task(id: appState.dataVersion) { await loadData() }
        .onAppear {
            viewMode = appState.config.accountsViewMode
            sortAscending = appState.config.accountsSortOrder == "asc"
        }
        .onChange(of: sortAscending) { appState.config.accountsSortOrder = sortAscending ? "asc" : "desc" }
        .onChange(of: viewMode) { Task { await loadData() } }
    }

    // MARK: - Flat View

    private var groupedBalances: [(key: String, rows: [AccountBalance])] {
        var groups: [(key: String, rows: [AccountBalance])] = []
        var currentKey = ""
        var currentRows: [AccountBalance] = []
        for row in filteredBalances {
            let topLevel = row.account.split(separator: ":").first.map(String.init) ?? row.account
            if topLevel != currentKey {
                if !currentRows.isEmpty { groups.append((key: currentKey, rows: currentRows)) }
                currentKey = topLevel
                currentRows = []
            }
            currentRows.append(row)
        }
        if !currentRows.isEmpty { groups.append((key: currentKey, rows: currentRows)) }
        if !sortAscending { groups.reverse() }
        return groups
    }

    private var flatView: some View {
        Group {
            if filteredBalances.isEmpty {
                ContentUnavailableView("No Accounts", systemImage: "building.columns",
                    description: Text(searchText.isEmpty ? "No accounts found in journal." : "No matching accounts."))
            } else {
                List {
                    ForEach(groupedBalances, id: \.key) { group in
                        Section {
                            ForEach(group.rows) { row in
                                AccountRow(
                                    label: row.account,
                                    value: row.formattedBalance,
                                    valueColor: row.balanceColor,
                                    onDrillDown: { drillDown = AccountDrillDown(accountName: row.account) }
                                )
                            }
                        } header: {
                            HStack {
                                Text(group.key)
                                if group.key == groupedBalances.first?.key {
                                    SortToggleButton(ascending: $sortAscending)
                                }
                            }
                        }
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
                    ForEach(filteredTree) { node in
                        AccountTreeNode(
                            node: node,
                            startExpanded: appState.config.accountsTreeExpanded,
                            formatBalance: formatNodeBalance,
                            balanceColor: nodeBalanceColor,
                            onDrillDown: { drillDown = AccountDrillDown(accountName: $0) }
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
        raw.trimmingCharacters(in: .whitespaces)
    }

    private func nodeBalanceColor(_ raw: String) -> Color {
        let (qty, _) = AmountParser.parse(raw)
        return qty < 0 ? .red : .secondary
    }
}

// MARK: - Account Tree Node

struct AccountTreeNode: View {
    let node: AccountNode
    let startExpanded: Bool
    let formatBalance: (String) -> String
    let balanceColor: (String) -> Color
    let onDrillDown: (String) -> Void

    @State private var isExpanded: Bool

    init(
        node: AccountNode,
        startExpanded: Bool,
        formatBalance: @escaping (String) -> String,
        balanceColor: @escaping (String) -> Color,
        onDrillDown: @escaping (String) -> Void
    ) {
        self.node = node
        self.startExpanded = startExpanded
        self.formatBalance = formatBalance
        self.balanceColor = balanceColor
        self.onDrillDown = onDrillDown
        self._isExpanded = State(initialValue: startExpanded)
    }

    var body: some View {
        if node.children.isEmpty {
            AccountRow(
                label: node.name,
                value: formatBalance(node.balance),
                valueColor: balanceColor(node.balance),
                onDrillDown: { onDrillDown(node.fullPath) }
            )
        } else {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(node.children) { child in
                    AccountTreeNode(
                        node: child,
                        startExpanded: startExpanded,
                        formatBalance: formatBalance,
                        balanceColor: balanceColor,
                        onDrillDown: onDrillDown
                    )
                }
            } label: {
                AccountRow(
                    label: node.name,
                    value: formatBalance(node.balance),
                    valueColor: balanceColor(node.balance),
                    onDrillDown: { onDrillDown(node.fullPath) }
                )
            }
        }
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
        rawBalance.trimmingCharacters(in: .whitespaces)
    }

    var balanceColor: Color {
        parsedAmount < 0 ? .red : .primary
    }
}
