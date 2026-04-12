/// Budget view: budget vs actual comparison with month navigation and CRUD.

import SwiftUI

struct BudgetView: View {
    @Environment(AppState.self) private var appState

    @State private var rules: [BudgetRule] = []
    @State private var actuals: [BudgetRow] = []
    @State private var isLoading = false
    @State private var showingForm = false
    @State private var editingRule: BudgetRule?
    @State private var showingDeleteConfirm = false
    @State private var ruleToDelete: BudgetRule?
    @State private var knownAccounts: [String] = []
    @State private var mergedRows: [MergedBudgetRow] = []
    @State private var selectedRow: MergedBudgetRow?
    @FocusState private var listFocused: Bool

    @State private var currentPeriod: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: Date())
    }()

    private var periodLabel: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        guard let date = f.date(from: currentPeriod) else { return currentPeriod }
        let display = DateFormatter()
        display.dateFormat = "MMMM yyyy"
        return display.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            PeriodNavigator(
                label: periodLabel,
                onPrevious: { previousMonth() },
                onNext: { nextMonth() }
            )

            Divider()

            // Content
            if isLoading {
                LoadingOverlay(message: "Loading budget...")
            } else if rules.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Budget Rules",
                    systemImage: "chart.bar",
                    description: Text("Add budget rules to track spending against targets.")
                )
                Spacer()
            } else {
                budgetList
            }
        }
        .navigationTitle("Budget")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { Task { await appState.reload() } } label: {
                    Label("Reload", systemImage: "arrow.triangle.2.circlepath")
                }

                Menu {
                    Button("Export as CSV") { ExportService.exportBudget(mergedRows, format: .csv) }
                    Button("Export as PDF") { ExportService.exportBudget(mergedRows, format: .pdf) }
                } label: {
                    Label("Export", systemImage: "arrow.down.doc")
                }
                .disabled(mergedRows.isEmpty)
                .help(mergedRows.isEmpty ? "No budget data to export" : "")

                Button { addRule() } label: {
                    Label("Add Rule", systemImage: "plus")
                }
            }
        }
        .background {
            Group {
                Button("") { if let row = selectedRow { editRule(row.rule) } }
                    .keyboardShortcut("e", modifiers: .command)
                Button("") { if let row = selectedRow { confirmDelete(row.rule) } }
                    .keyboardShortcut(.delete, modifiers: .command)
                Button("") { selectFirst() }
                    .keyboardShortcut(.tab, modifiers: [])
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        .task(id: appState.dataVersion) { await loadData() }
        .onChange(of: currentPeriod) { Task { await loadData() } }
        .onChange(of: appState.showingNewBudgetRule) {
            if appState.showingNewBudgetRule {
                appState.showingNewBudgetRule = false
                addRule()
            }
        }
        .sheet(isPresented: $showingForm) {
            BudgetFormView(
                editingRule: editingRule,
                knownAccounts: knownAccounts
            ) { newRule in
                Task { await saveRule(newRule) }
            }
            .environment(appState)
        }
        .confirmDeleteAlert(
            isPresented: $showingDeleteConfirm,
            itemName: "Budget Rule",
            message: ruleToDelete.map { "Remove budget for \($0.account)?" } ?? "",
            onConfirm: { Task { await performDelete() } }
        )
    }

    // MARK: - Budget List

    private var budgetList: some View {
        List(selection: $selectedRow) {
            BudgetHeaderRow()
                .listRowSeparator(.hidden)

            ForEach(mergedRows) { row in
                BudgetRowView(row: row)
                    .tag(row)
                    .contextMenu {
                        Button("Edit") { editRule(row.rule) }
                        Divider()
                        Button("Delete", role: .destructive) { confirmDelete(row.rule) }
                    }
            }
        }
        .listStyle(.inset)
        .focused($listFocused)
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard let backend = appState.activeBackend else { return }
        isLoading = true

        let budgetPath = BudgetManager.budgetPath(for: backend.journalFile)
        rules = BudgetManager.parseRules(budgetPath: budgetPath)

        do {
            actuals = try await backend.loadBudgetReport(period: currentPeriod)
            knownAccounts = try await backend.loadAccounts()
        } catch {
            appState.errorMessage = error.localizedDescription
        }

        mergedRows = rules.map { rule in
            let actual = actuals.first { $0.account == rule.account }
            return MergedBudgetRow(
                rule: rule,
                actual: actual?.actual ?? 0,
                budget: rule.amount.quantity,
                commodity: rule.amount.commodity
            )
        }.sorted { $0.rule.account < $1.rule.account }

        isLoading = false
    }

    // MARK: - Navigation

    private func previousMonth() {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        guard let date = f.date(from: currentPeriod),
              let adjusted = Calendar.current.date(byAdding: .month, value: -1, to: date) else { return }
        currentPeriod = f.string(from: adjusted)
    }

    private func nextMonth() {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        guard let date = f.date(from: currentPeriod),
              let adjusted = Calendar.current.date(byAdding: .month, value: 1, to: date) else { return }
        currentPeriod = f.string(from: adjusted)
    }

    // MARK: - CRUD Actions

    private func selectFirst() {
        if let first = mergedRows.first {
            selectedRow = first
            listFocused = true
        }
    }

    private func addRule() {
        editingRule = nil
        showingForm = true
    }

    private func editRule(_ rule: BudgetRule) {
        editingRule = rule
        showingForm = true
    }

    private func confirmDelete(_ rule: BudgetRule) {
        ruleToDelete = rule
        showingDeleteConfirm = true
    }

    private func saveRule(_ newRule: BudgetRule) async {
        guard let backend = appState.activeBackend else { return }
        do {
            if let editing = editingRule {
                try await BudgetManager.updateRule(
                    oldAccount: editing.account,
                    newRule: newRule,
                    journalFile: backend.journalFile,
                    validator: backend
                )
            } else {
                try await BudgetManager.addRule(
                    newRule,
                    journalFile: backend.journalFile,
                    validator: backend
                )
            }
            await loadData()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func performDelete() async {
        guard let rule = ruleToDelete, let backend = appState.activeBackend else { return }
        do {
            try await BudgetManager.deleteRule(
                account: rule.account,
                journalFile: backend.journalFile,
                validator: backend
            )
            await loadData()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
        ruleToDelete = nil
    }
}

// MARK: - Merged Budget Row

struct MergedBudgetRow: Identifiable, Hashable {
    let id = UUID()
    let rule: BudgetRule
    let actual: Decimal
    let budget: Decimal
    let commodity: String

    static func == (lhs: MergedBudgetRow, rhs: MergedBudgetRow) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var remaining: Decimal { budget - actual }
    var usagePct: Double {
        guard budget != 0 else { return 0 }
        return NSDecimalNumber(decimal: actual / budget * 100).doubleValue
    }
}

// MARK: - Budget Header Row

struct BudgetHeaderRow: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("Account")
                .frame(width: 200, alignment: .leading)
            Text("Budget")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("Actual")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("Remaining")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("Usage")
                .frame(width: 60, alignment: .trailing)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.vertical, ListMetrics.rowPadding)
    }
}

// MARK: - Budget Row View

struct BudgetRowView: View {
    let row: MergedBudgetRow

    private var usageColor: Color {
        if row.usagePct > 100 { return .red }
        if row.usagePct > 75 { return .orange }
        return .green
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(row.rule.account)
                .font(.callout)
                .lineLimit(1)
                .frame(width: 200, alignment: .leading)

            Text(AmountFormatter.format(row.budget, commodity: row.commodity))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(AmountFormatter.format(row.actual, commodity: row.commodity))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(usageColor)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(AmountFormatter.format(row.remaining, commodity: row.commodity))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(row.remaining >= 0 ? .green : .red)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text((row.usagePct / 100).formatted(.percent.precision(.fractionLength(0))))
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(usageColor)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, ListMetrics.rowPadding)
    }
}
