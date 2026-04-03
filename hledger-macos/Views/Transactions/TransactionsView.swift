/// Transactions view with navigable month, income/expense header, and transaction list.

import SwiftUI

struct TransactionsView: View {
    @Environment(AppState.self) private var appState

    @State private var selectedTransaction: Transaction?
    @State private var formConfig: FormConfig?
    @State private var showingDeleteConfirm = false
    @State private var transactionToDelete: Transaction?

    @State private var periodSummary: PeriodSummary?
    @FocusState private var listFocused: Bool

    var body: some View {
        @Bindable var state = appState
        VStack(spacing: 0) {
            // Period navigator
            HStack {
                Button(action: { appState.previousMonth() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.leftArrow, modifiers: [])

                Spacer()

                Text(appState.periodLabel)
                    .font(.title2.bold())

                Spacer()

                Button(action: { appState.nextMonth() }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.rightArrow, modifiers: [])
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)

            // Income / Expenses cards (always visible)
            HStack(spacing: 16) {
                SummaryCard(title: "Income", summary: periodSummary, value: \.income, color: .green)
                SummaryCard(title: "Expenses", summary: periodSummary, value: \.expenses, color: .red)
                SummaryCard(
                    title: "Net", summary: periodSummary, value: \.net,
                    color: (periodSummary?.net ?? 0) >= 0 ? .green : .red,
                    subtitle: SummaryCard.netSubtitle(for: periodSummary)
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()

            // Transaction list
            if appState.isLoading {
                Spacer()
                ProgressView("Loading transactions...")
                Spacer()
            } else if appState.transactions.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Transactions",
                    systemImage: "doc.text",
                    description: Text("No transactions found for \(appState.periodLabel).")
                )
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
                Menu {
                    Button("Export as CSV") { ExportService.exportTransactions(appState.transactions, format: .csv) }
                    Button("Export as PDF") { ExportService.exportTransactions(appState.transactions, format: .pdf) }
                } label: {
                    Label("Export", systemImage: "arrow.down.doc")
                }
                .disabled(appState.transactions.isEmpty)

                Button(action: { newTransaction() }) {
                    Label("New Transaction", systemImage: "plus")
                }
            }
        }
        // Hidden keyboard shortcuts
        .background {
            Group {
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
        }
        .onChange(of: appState.showingNewTransaction) {
            if appState.showingNewTransaction {
                appState.showingNewTransaction = false
                newTransaction()
            }
        }
        .task(id: appState.dataVersion) { await loadAll() }
        .onChange(of: appState.currentPeriod) {
            Task { await loadAll() }
        }
        .sheet(item: $formConfig) { config in
            TransactionFormView(editingTransaction: config.transaction, isClone: config.isClone)
                .environment(appState)
        }
        .alert("Delete Transaction?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await performDelete() } }
        } message: {
            if let txn = transactionToDelete {
                Text("\(txn.date) \(txn.status.symbol) \(txn.description)\n\(txn.postings.map(\.account).joined(separator: "\n"))")
            }
        }
    }

    // MARK: - Data Loading

    private func loadAll() async {
        async let txns: () = appState.loadTransactions()
        async let summary: () = loadPeriodSummary()
        _ = await (txns, summary)
    }

    private func loadPeriodSummary() async {
        guard let backend = appState.activeBackend else { return }
        periodSummary = try? await backend.loadPeriodSummary(period: appState.currentPeriod)
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
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { editTransaction(transaction) }
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
            await appState.loadTransactions()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func performDelete() async {
        guard let txn = transactionToDelete, let backend = appState.activeBackend else { return }
        do {
            try await backend.deleteTransaction(txn)
            await appState.loadTransactions()
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
                    .foregroundStyle(.orange)
                    .frame(width: 14)
            } else {
                Text(transaction.status.symbol)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(statusColor)
                    .frame(width: 14)
            }

            Text(transaction.typeIndicator)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(typeColor)
                .frame(width: 14)

            Text(transaction.date)
                .font(.system(.callout, design: .monospaced))
                .italic(isFuture)
                .foregroundStyle(isFuture ? .orange : .secondary)

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
    }

    private var statusColor: Color {
        switch transaction.status {
        case .cleared: return .green
        case .pending: return .orange
        case .unmarked: return .secondary
        }
    }

    private var typeColor: Color {
        switch transaction.typeIndicator {
        case "I": return .green
        case "E": return .red
        default: return .secondary
        }
    }

    private var amountColor: Color {
        transaction.typeIndicator == "I" ? .green : .primary
    }
}
