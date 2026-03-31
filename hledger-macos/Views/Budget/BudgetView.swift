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

    /// Merged data: rule + actual for each budget account.
    private var mergedRows: [MergedBudgetRow] {
        rules.map { rule in
            let actual = actuals.first { $0.account == rule.account }
            let actualAmount = actual?.actual ?? 0
            let budgetAmount = rule.amount.quantity
            return MergedBudgetRow(
                rule: rule,
                actual: actualAmount,
                budget: budgetAmount,
                commodity: rule.amount.commodity
            )
        }.sorted { $0.rule.account < $1.rule.account }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Period navigator
            HStack {
                Button(action: { previousMonth() }) {
                    Image(systemName: "chevron.left").font(.title3)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.leftArrow, modifiers: [])

                Spacer()
                Text(periodLabel).font(.title2.bold())
                Spacer()

                Button(action: { nextMonth() }) {
                    Image(systemName: "chevron.right").font(.title3)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.rightArrow, modifiers: [])
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)

            Divider()

            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading budget...")
                Spacer()
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
            ToolbarItem(placement: .primaryAction) {
                Button { addRule() } label: {
                    Label("Add Rule", systemImage: "plus")
                }
            }
        }
        .task { await loadData() }
        .onChange(of: currentPeriod) { Task { await loadData() } }
        .sheet(isPresented: $showingForm) {
            BudgetFormView(
                editingRule: editingRule,
                knownAccounts: knownAccounts
            ) { newRule in
                Task { await saveRule(newRule) }
            }
        }
        .alert("Delete Budget Rule?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await performDelete() } }
        } message: {
            if let rule = ruleToDelete {
                Text("Remove budget for \(rule.account)?")
            }
        }
    }

    // MARK: - Budget List

    private var budgetList: some View {
        List {
            // Header
            HStack(spacing: 0) {
                Text("Account").frame(width: 200, alignment: .leading)
                Text("Budget").frame(maxWidth: .infinity, alignment: .trailing)
                Text("Actual").frame(maxWidth: .infinity, alignment: .trailing)
                Text("Remaining").frame(maxWidth: .infinity, alignment: .trailing)
                Text("Used").frame(width: 60, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            ForEach(mergedRows) { row in
                BudgetRowView(row: row)
                    .contextMenu {
                        Button("Edit") { editRule(row.rule) }
                        Divider()
                        Button("Delete", role: .destructive) { confirmDelete(row.rule) }
                    }
            }
        }
        .listStyle(.inset)
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

struct MergedBudgetRow: Identifiable {
    let id = UUID()
    let rule: BudgetRule
    let actual: Decimal
    let budget: Decimal
    let commodity: String

    var remaining: Decimal { budget - actual }
    var usagePct: Double {
        guard budget != 0 else { return 0 }
        return NSDecimalNumber(decimal: actual / budget * 100).doubleValue
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

            Text("\(Int(row.usagePct))%")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(usageColor)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, ListMetrics.rowPadding)
    }
}
