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
    @State private var isGenerating = false
    @State private var showingGenerateConfirm = false
    @State private var pendingSummary: [(RecurringRule, Int)] = []
    @FocusState private var listFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                LoadingOverlay(message: "Loading rules...")
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
            ToolbarItemGroup(placement: .primaryAction) {
                Button { Task { await appState.reload() } } label: {
                    Label("Reload", systemImage: "arrow.triangle.2.circlepath")
                }

                Button { Task { await previewGenerate() } } label: {
                    if isGenerating {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Generate", systemImage: "play.fill")
                    }
                }
                .disabled(rules.isEmpty || isGenerating)

                Button { addRule() } label: {
                    Label("Add Rule", systemImage: "plus")
                }
            }
        }
        .background {
            Group {
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
        .task(id: appState.dataVersion) { await loadData() }
        .onChange(of: appState.showingNewRecurringRule) {
            if appState.showingNewRecurringRule {
                appState.showingNewRecurringRule = false
                addRule()
            }
        }
        .sheet(isPresented: $showingForm) {
            RecurringFormView(
                editingRule: editingRule,
                knownAccounts: knownAccounts
            ) { newRule in
                Task { await saveRule(newRule) }
            }
            .environment(appState)
        }
        .confirmDeleteAlert(
            isPresented: $showingDeleteConfirm,
            itemName: "Recurring Rule",
            message: ruleToDelete.map { "Remove recurring rule \"\($0.description)\" (\($0.periodExpr))?" } ?? "",
            onConfirm: { Task { await performDelete() } }
        )
        .alert("Generate Transactions?", isPresented: $showingGenerateConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Generate") { Task { await generateAll() } }
        } message: {
            let total = pendingSummary.reduce(0) { $0 + $1.1 }
            if total == 0 {
                Text("No pending transactions to generate. All rules are up to date.")
            } else {
                Text(generateSummaryText())
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
        rules = RecurringManager.parseRules(recurringPath: path, commodityStyles: appState.commodityStyles)
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
                    validator: backend,
                    commodityStyles: appState.commodityStyles
                )
            } else {
                try await RecurringManager.addRule(
                    newRule,
                    journalFile: backend.journalFile,
                    validator: backend,
                    commodityStyles: appState.commodityStyles
                )
            }
            await loadData()
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }

    private func previewGenerate() async {
        guard let backend = appState.activeBackend else { return }
        isGenerating = true
        var summary: [(RecurringRule, Int)] = []
        for rule in rules {
            let pending = await RecurringManager.computePending(rule: rule, backend: backend)
            if !pending.isEmpty {
                summary.append((rule, pending.count))
            }
        }
        pendingSummary = summary
        isGenerating = false
        showingGenerateConfirm = true
    }

    private func generateSummaryText() -> String {
        let lines = pendingSummary.map { rule, count in
            "\(rule.description): \(count) transaction\(count == 1 ? "" : "s")"
        }
        let total = pendingSummary.reduce(0) { $0 + $1.1 }
        return lines.joined(separator: "\n") + "\n\nTotal: \(total) transaction\(total == 1 ? "" : "s")"
    }

    private func generateAll() async {
        guard let backend = appState.activeBackend else { return }
        isGenerating = true
        var totalGenerated = 0

        for rule in rules {
            let pending = await RecurringManager.computePending(rule: rule, backend: backend)
            if !pending.isEmpty {
                do {
                    try await RecurringManager.generateTransactions(rule: rule, dates: pending, backend: backend)
                    totalGenerated += pending.count
                } catch {
                    appState.errorMessage = error.localizedDescription
                }
            }
        }

        isGenerating = false
    }

    private func performDelete() async {
        guard let rule = ruleToDelete, let backend = appState.activeBackend else { return }
        do {
            try await RecurringManager.deleteRule(
                ruleId: rule.ruleId,
                journalFile: backend.journalFile,
                validator: backend,
                commodityStyles: appState.commodityStyles
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
