/// Recurring transactions view: list rules with CRUD and keyboard navigation.

import SwiftUI

struct RecurringView: View {
    @Environment(AppState.self) private var appState

    @State private var rules: [RecurringRule] = []
    @State private var isLoading = false
    @State private var showingForm = false
    @State private var editingRule: RecurringRule?
    @State private var showingDeleteConfirm = false
    @State private var ruleToDelete: RecurringRule?
    @State private var selectedRule: RecurringRule?
    @State private var knownAccounts: [String] = []
    @FocusState private var listFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView("Loading rules...")
                Spacer()
            } else if rules.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Recurring Rules",
                    systemImage: "repeat",
                    description: Text("Add recurring rules to automate periodic transactions.")
                )
                Spacer()
            } else {
                rulesList
            }
        }
        .navigationTitle("Recurring")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { addRule() } label: {
                    Label("Add Rule", systemImage: "plus")
                }
            }
        }
        .background {
            Group {
                Button("") { addRule() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("") { if let r = selectedRule { editRule(r) } }
                    .keyboardShortcut("e", modifiers: .command)
                Button("") { if let r = selectedRule { confirmDelete(r) } }
                    .keyboardShortcut(.delete, modifiers: .command)
                Button("") { selectFirst() }
                    .keyboardShortcut(.tab, modifiers: [])
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        .task { await loadData() }
        .sheet(isPresented: $showingForm) {
            RecurringFormView(
                editingRule: editingRule,
                knownAccounts: knownAccounts
            ) { newRule in
                Task { await saveRule(newRule) }
            }
        }
        .alert("Delete Recurring Rule?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await performDelete() } }
        } message: {
            if let rule = ruleToDelete {
                Text("Remove recurring rule \"\(rule.description)\" (\(rule.periodExpr))?")
            }
        }
    }

    // MARK: - List

    private var rulesList: some View {
        List(rules, selection: $selectedRule) { rule in
            RecurringRuleRow(rule: rule)
                .tag(rule)
                .contextMenu {
                    Button("Edit") { editRule(rule) }
                    Divider()
                    Button("Delete", role: .destructive) { confirmDelete(rule) }
                }
        }
        .listStyle(.inset)
        .focused($listFocused)
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard let backend = appState.activeBackend else { return }
        isLoading = true
        let path = RecurringManager.recurringPath(for: backend.journalFile)
        rules = RecurringManager.parseRules(recurringPath: path)
        knownAccounts = (try? await backend.loadAccounts()) ?? []
        isLoading = false
    }

    // MARK: - Actions

    private func selectFirst() {
        if let first = rules.first {
            selectedRule = first
            listFocused = true
        }
    }

    private func addRule() {
        editingRule = nil
        showingForm = true
    }

    private func editRule(_ rule: RecurringRule) {
        editingRule = rule
        showingForm = true
    }

    private func confirmDelete(_ rule: RecurringRule) {
        ruleToDelete = rule
        showingDeleteConfirm = true
    }

    private func saveRule(_ newRule: RecurringRule) async {
        guard let backend = appState.activeBackend else { return }
        do {
            if let editing = editingRule {
                try await RecurringManager.updateRule(
                    ruleId: editing.ruleId,
                    newRule: newRule,
                    journalFile: backend.journalFile,
                    validator: backend
                )
            } else {
                try await RecurringManager.addRule(
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
            try await RecurringManager.deleteRule(
                ruleId: rule.ruleId,
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

// MARK: - Rule Row

struct RecurringRuleRow: View {
    let rule: RecurringRule

    var body: some View {
        HStack(spacing: 12) {
            // Period badge
            Text(rule.periodExpr)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))

            // Description
            VStack(alignment: .leading, spacing: 1) {
                Text(rule.description.isEmpty ? "No description" : rule.description)
                    .font(rule.description.isEmpty ? .callout.italic() : .callout)
                    .foregroundStyle(rule.description.isEmpty ? .tertiary : .primary)
                    .lineLimit(1)

                Text(rule.postings.map(\.account).joined(separator: " \u{2192} "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Amount (first posting with amount)
            if let amount = rule.postings.first(where: { !$0.amounts.isEmpty })?.amounts.first {
                Text(AmountFormatter.format(amount.quantity, commodity: amount.commodity))
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            // Date range
            VStack(alignment: .trailing, spacing: 1) {
                if let start = rule.startDate {
                    Text("from \(start)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if let end = rule.endDate {
                    Text("to \(end)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, ListMetrics.rowPadding)
    }
}
