/// Transactions view with navigable month, income/expense header, and transaction list.

import SwiftUI

struct TransactionsView: View {
    @Environment(AppState.self) private var appState

    @State private var selectedTransaction: Transaction?
    @State private var formConfig: FormConfig?
    @State private var showingDeleteConfirm = false
    @State private var transactionToDelete: Transaction?
    @State private var showingCsvImport = false

    @FocusState private var listFocused: Bool

    var body: some View {
        @Bindable var state = appState
        VStack(spacing: 0) {
            PeriodNavigator(
                label: appState.periodLabel,
                onPrevious: { appState.previousMonth() },
                onNext: { appState.nextMonth() }
            )

            // Income / Expenses cards (always visible)
            HStack(spacing: 16) {
                SummaryCard(title: "Income", summary: appState.summaryCurrentMonth, value: \.income, color: Theme.AccountCategory.income)
                SummaryCard(title: "Expenses", summary: appState.summaryCurrentMonth, value: \.expenses, color: Theme.AccountCategory.expense)
                SummaryCard(
                    title: "Net", summary: appState.summaryCurrentMonth, value: \.net,
                    color: (appState.summaryCurrentMonth?.net ?? 0) >= 0 ? Theme.Delta.positive : Theme.Delta.negative,
                    subtitle: SummaryCard.netSubtitle(for: appState.summaryCurrentMonth)
                )
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)

            Divider()

            // Transaction list
            if appState.isLoading {
                LoadingOverlay(message: "Loading transactions...")
            } else if appState.transactions.isEmpty {
                Spacer()
                if !appState.searchQuery.isEmpty {
                    ContentUnavailableView.search(text: appState.searchQuery)
                } else if (appState.journalStats?.transactionCount ?? 0) == 0 {
                    ContentUnavailableView {
                        Label("Journal is Empty", systemImage: "doc.badge.plus")
                    } description: {
                        Text("Add your first transaction to start tracking your finances.")
                    } actions: {
                        Button("Add Transaction") { newTransaction() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ContentUnavailableView {
                        Label("No Transactions in \(appState.periodLabel)", systemImage: "calendar.badge.exclamationmark")
                    } description: {
                        Text("There are no transactions recorded for this period.")
                    } actions: {
                        Button("Add Transaction") { newTransaction() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                Spacer()
            } else {
                let todayStr = {
                    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
                    return f.string(from: Date())
                }()
                let futureTransactions = appState.transactions.filter { $0.date > todayStr }
                let pastTransactions = appState.transactions.filter { $0.date <= todayStr }

                List(selection: $selectedTransaction) {
                    ForEach(futureTransactions) { transaction in
                        transactionRow(transaction)
                    }

                    if !futureTransactions.isEmpty && !pastTransactions.isEmpty {
                        Divider()
                            .listRowSeparator(.hidden)
                            .frame(height: 4)
                    }

                    ForEach(pastTransactions) { transaction in
                        transactionRow(transaction)
                    }
                }
                .listStyle(.inset)
                .focused($listFocused)
            }
        }
        .searchable(text: $state.searchQuery, prompt: "Search: desc:, acct:, amt:, tag:, status:")
        .searchSuggestions {
            if appState.searchQuery.isEmpty {
                Section("Filters") {
                    searchSuggestion("desc:", label: "Description", icon: "text.quote")
                    searchSuggestion("acct:", label: "Account", icon: "building.columns")
                    searchSuggestion("amt:>", label: "Amount greater than", icon: "number")
                    searchSuggestion("amt:<", label: "Amount less than", icon: "number")
                    searchSuggestion("tag:", label: "Tag", icon: "tag")
                    searchSuggestion("status:*", label: "Cleared", icon: "checkmark.circle")
                    searchSuggestion("status:!", label: "Pending", icon: "exclamationmark.circle")
                }
                Section("Shortcuts") {
                    searchSuggestion("d:", label: "desc: (short)", icon: "text.quote")
                    searchSuggestion("ac:", label: "acct: (short)", icon: "building.columns")
                    searchSuggestion("am:", label: "amt: (short)", icon: "number")
                }
            }
        }
        .onSubmit(of: .search) {
            Task { await appState.loadTransactions() }
        }
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { Task { await appState.reload() } } label: {
                    Label("Reload", systemImage: "arrow.triangle.2.circlepath")
                }

                Menu {
                    Button { showingCsvImport = true } label: {
                        Label("Import CSV", systemImage: "square.and.arrow.down")
                    }

                    Divider()

                    Button { ExportService.exportTransactions(appState.transactions, format: .csv) } label: {
                        Label("Export as CSV", systemImage: "arrow.down.doc")
                    }
                    .disabled(appState.transactions.isEmpty)
                    .help(appState.transactions.isEmpty ? "No transactions to export" : "")

                    Button { ExportService.exportTransactions(appState.transactions, format: .pdf) } label: {
                        Label("Export as PDF", systemImage: "doc.richtext")
                    }
                    .disabled(appState.transactions.isEmpty)
                    .help(appState.transactions.isEmpty ? "No transactions to export" : "")
                } label: {
                    Label("Import & Export", systemImage: "doc.badge.gearshape")
                }

                Button(action: { newTransaction() }) {
                    Label("New Transaction", systemImage: "plus")
                }
            }
        }
        // Hidden keyboard shortcuts
        .background {
            Group {
                Button("") { showingCsvImport = true }
                    .keyboardShortcut("i", modifiers: .command)
                Button("") { editTransaction(selectedTransaction) }
                    .keyboardShortcut("e", modifiers: .command)
                Button("") { cloneTransaction(selectedTransaction) }
                    .keyboardShortcut("d", modifiers: .command)
                Button("") { if let s = selectedTransaction { confirmDelete(s) } }
                    .keyboardShortcut(.delete, modifiers: .command)
                Button("") { goToCurrentMonth() }
                    .keyboardShortcut("t", modifiers: .command)
                Button("") { selectFirstTransaction() }
                    .keyboardShortcut(.tab, modifiers: [])
            }
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
        }
        .onChange(of: appState.showingNewTransaction) {
            if appState.showingNewTransaction {
                appState.showingNewTransaction = false
                newTransaction()
            }
        }
        .task {
            await loadAll()
            // Handle deferred ⌘N from another section (e.g. Summary → Transactions)
            if appState.showingNewTransaction {
                appState.showingNewTransaction = false
                newTransaction()
            }
        }
        .onChange(of: appState.currentPeriod) {
            Task { await loadAll() }
        }
        .onChange(of: appState.searchQuery) { oldValue, newValue in
            if newValue.isEmpty && !oldValue.isEmpty {
                Task { await loadAll() }
            }
        }
        .sheet(item: $formConfig) { config in
            TransactionFormView(editingTransaction: config.transaction, isClone: config.isClone)
                .environment(appState)
        }
        .sheet(isPresented: $showingCsvImport) {
            CsvImportSheet()
                .environment(appState)
        }
        .confirmDeleteAlert(
            isPresented: $showingDeleteConfirm,
            itemName: "Transaction",
            message: transactionToDelete.map { "\($0.date) \($0.status.symbol) \($0.description)\n\($0.postings.map(\.account).joined(separator: "\n"))" } ?? "",
            onConfirm: { Task { await performDelete() } }
        )
    }

    // MARK: - Data Loading

    private func loadAll() async {
        async let txns: () = appState.loadTransactions()
        async let summary: () = appState.loadPeriodSummary()
        _ = await (txns, summary)
    }

    private func selectFirstTransaction() {
        if let first = appState.transactions.first {
            selectedTransaction = first
            listFocused = true
        }
    }

    // MARK: - Transaction Row

    @ViewBuilder
    private func transactionRow(_ transaction: Transaction) -> some View {
        TransactionRowView(transaction: transaction)
            .tag(transaction)
            .contextMenu {
                Button("Edit") { editTransaction(transaction) }
                Button("Clone") { cloneTransaction(transaction) }
                Divider()
                Menu("Set Status") {
                    Button("Cleared *") { Task { await toggleStatus(transaction, to: .cleared) } }
                    Button("Pending !") { Task { await toggleStatus(transaction, to: .pending) } }
                    Button("Unmarked") { Task { await toggleStatus(transaction, to: .unmarked) } }
                }
                Divider()
                Button("Delete", role: .destructive) { confirmDelete(transaction) }
            }
    }

    // MARK: - Search Suggestion Helper

    private func searchSuggestion(_ query: String, label: String, icon: String) -> some View {
        Button {
            appState.searchQuery = query
        } label: {
            Label(label, systemImage: icon)
        }
        .searchCompletion(query)
    }

    // MARK: - Actions

    private func goToCurrentMonth() {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        appState.currentPeriod = f.string(from: Date())
    }

    private func newTransaction() {
        formConfig = FormConfig(transaction: nil, isClone: false)
    }

    private func editTransaction(_ transaction: Transaction?) {
        guard let transaction else { return }
        formConfig = FormConfig(transaction: transaction, isClone: false)
    }

    private func cloneTransaction(_ transaction: Transaction?) {
        guard let transaction else { return }
        formConfig = FormConfig(transaction: transaction, isClone: true)
    }

    private func confirmDelete(_ transaction: Transaction) {
        transactionToDelete = transaction
        showingDeleteConfirm = true
    }

    private func toggleStatus(_ transaction: Transaction, to newStatus: TransactionStatus) async {
        guard let backend = appState.activeBackend else { return }
        do {
            try await backend.updateTransactionStatus(transaction, to: newStatus)
            await appState.reloadAfterWrite()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func performDelete() async {
        guard let txn = transactionToDelete, let backend = appState.activeBackend else { return }
        do {
            try await backend.deleteTransaction(txn)
            await appState.reloadAfterWrite()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
        transactionToDelete = nil
    }
}

// MARK: - Form Config

struct FormConfig: Identifiable {
    let id = UUID()
    let transaction: Transaction?
    let isClone: Bool
}

// MARK: - Transaction Row

struct TransactionRowView: View {
    let transaction: Transaction

    private var isFuture: Bool {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: transaction.date) else { return false }
        return date > Date()
    }

    var body: some View {
        HStack(spacing: 12) {
            if isFuture {
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(Theme.Status.warning)
                    .frame(width: 14)
                    .accessibilityHidden(true)
            } else {
                Text(transaction.status.symbol)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(statusColor)
                    .frame(width: 14)
                    .accessibilityHidden(true)
            }

            Text(transaction.typeIndicator)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(typeColor)
                .frame(width: 14)
                .accessibilityHidden(true)

            Text(transaction.date)
                .font(.system(.callout, design: .monospaced))
                .italic(isFuture)
                .foregroundStyle(isFuture ? Theme.Status.warning : .secondary)

            HStack(spacing: 4) {
                Text(transaction.description.isEmpty ? "no description" : transaction.description)
                    .font(isFuture ? .callout.italic() : (transaction.description.isEmpty ? .callout.italic() : .callout))
                    .foregroundStyle(transaction.description.isEmpty ? .tertiary : (isFuture ? .secondary : .primary))
                    .lineLimit(1)

                if !transaction.code.isEmpty {
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text(transaction.code)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(transaction.totalAmount)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(isFuture ? .secondary : amountColor)
        }
        .padding(.vertical, ListMetrics.rowPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        if isFuture {
            parts.append("Scheduled")
        } else {
            switch transaction.status {
            case .cleared: parts.append("Cleared")
            case .pending: parts.append("Pending")
            case .unmarked: parts.append("Unmarked")
            }
        }
        switch transaction.typeIndicator {
        case "I": parts.append("income")
        case "E": parts.append("expense")
        default: break
        }
        parts.append(transaction.date)
        if !transaction.description.isEmpty { parts.append(transaction.description) }
        parts.append(transaction.totalAmount)
        return parts.joined(separator: ", ")
    }

    private var statusColor: Color {
        switch transaction.status {
        case .cleared: return Theme.Status.good
        case .pending: return Theme.Status.warning
        case .unmarked: return .secondary
        }
    }

    private var typeColor: Color {
        switch transaction.typeIndicator {
        case "I": return Theme.AccountCategory.income
        case "E": return Theme.AccountCategory.expense
        default: return .secondary
        }
    }

    private var amountColor: Color {
        transaction.typeIndicator == "I" ? Theme.Delta.positive : .primary
    }
}
