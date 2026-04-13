/// Multi-section rules editor for creating and editing hledger CSV rules files.
///
/// Can be used standalone (from Rules Manager) or embedded in the import wizard.
/// Sections: Column Mapping, Settings, Conditional Rules, Raw Editor.

import SwiftUI

struct CsvRulesEditorView: View {
    @Binding var config: CsvRulesConfig
    let csvContent: String
    let knownAccounts: [String]
    let knownCommodities: [String]

    @State private var showRawEditor = false
    @State private var rawText = ""
    @State private var rawParseError: String?
    @State private var editingConditionalRule: ConditionalRule?
    @State private var showingConditionalForm = false
    @State private var selectedConditionalRule: ConditionalRule?

    /// CSV sample rows for the column mapping preview.
    private var sampleRows: [[String]] {
        let rows = CsvRulesManager.parseRawCsv(csvContent, separator: config.separator, skipLines: config.skipLines)
        return Array(rows.prefix(5))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !csvContent.isEmpty {
                    columnMappingSection
                }
                settingsSection
                conditionalRulesSection
                rawEditorSection
            }
            .padding(Theme.Spacing.xl)
        }
    }

    // MARK: - Column Mapping

    @ViewBuilder
    private var columnMappingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Column Mapping", systemImage: "tablecells")
                .font(.headline)

            if config.columnMappings.isEmpty {
                Text("Load a CSV file to see column mappings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                // Header row
                HStack(spacing: 0) {
                    Text("CSV Column")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Sample")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Assign to")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.Spacing.sm)

                ForEach(config.columnMappings.indices, id: \.self) { index in
                    columnMappingRow(index: index)
                }
            }
        }
        .padding(Theme.Spacing.mdPlus)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func columnMappingRow(index: Int) -> some View {
        HStack(spacing: 0) {
            Text(config.columnMappings[index].csvColumnHeader)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            Text(config.columnMappings[index].sampleValue)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            Picker("", selection: $config.columnMappings[index].assignedField) {
                Text("(skip)")
                    .tag(nil as HledgerField?)
                ForEach(HledgerField.allCases) { field in
                    Text(field.displayName).tag(field as HledgerField?)
                }
            }
            .labelsHidden()
            .frame(minWidth: 140)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xxs)
    }

    // MARK: - Settings

    @ViewBuilder
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Settings", systemImage: "gearshape")
                .font(.headline)

            VStack(spacing: 12) {
                FormRow("Name:", labelWidth: 100) {
                    TextField("e.g. My Bank", text: $config.name)
                        .textFieldStyle(.roundedBorder)
                }

                FormRow("Account:", labelWidth: 100) {
                    AutocompleteField(
                        placeholder: "e.g. assets:bank:checking",
                        text: $config.defaultAccount,
                        suggestions: knownAccounts
                    )
                }

                FormRow("Currency:", labelWidth: 100) {
                    AutocompleteField(
                        placeholder: "e.g. EUR",
                        text: $config.defaultCurrency,
                        suggestions: knownCommodities
                    )
                }

                FormRow("Date format:", labelWidth: 100) {
                    HStack {
                        Picker("", selection: $config.dateFormat) {
                            Text("YYYY-MM-DD").tag("%Y-%m-%d")
                            Text("DD/MM/YYYY").tag("%d/%m/%Y")
                            Text("MM/DD/YYYY").tag("%m/%d/%Y")
                            Text("DD-MM-YYYY").tag("%d-%m-%Y")
                            Text("DD.MM.YYYY").tag("%d.%m.%Y")
                            Text("YYYY/MM/DD").tag("%Y/%m/%d")
                        }
                        .labelsHidden()
                        Spacer()
                    }
                }

                FormRow("Separator:", labelWidth: 100) {
                    HStack {
                        Picker("", selection: $config.separator) {
                            ForEach(CsvSeparator.allCases) { sep in
                                Text(sep.displayName).tag(sep)
                            }
                        }
                        .labelsHidden()
                        Spacer()
                    }
                }

                FormRow("Skip rows:", labelWidth: 100) {
                    HStack {
                        Stepper(value: $config.skipLines, in: 0...10) {
                            Text("\(config.skipLines)")
                                .font(.callout.monospaced())
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(Theme.Spacing.mdPlus)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Conditional Rules

    @ViewBuilder
    private var conditionalRulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Conditional Rules", systemImage: "arrow.triangle.branch")
                    .font(.headline)

                Spacer()

                Button {
                    editingConditionalRule = nil
                    showingConditionalForm = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.callout)
                }
            }

            if config.conditionalRules.isEmpty {
                Text("No conditional rules. Add rules to auto-categorize transactions by pattern.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                // Header
                HStack(spacing: 0) {
                    Text("Pattern")
                        .frame(width: 200, alignment: .leading)
                    Text("Account")
                        .frame(minWidth: 200, alignment: .leading)
                    Spacer()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.Spacing.sm)

                ForEach(config.conditionalRules) { rule in
                    conditionalRuleRow(rule)
                }
            }
        }
        .padding(Theme.Spacing.mdPlus)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        .sheet(isPresented: $showingConditionalForm) {
            ConditionalRuleFormView(
                editingRule: editingConditionalRule,
                knownAccounts: knownAccounts
            ) { saved in
                if let idx = config.conditionalRules.firstIndex(where: { $0.id == saved.id }) {
                    config.conditionalRules[idx] = saved
                } else {
                    config.conditionalRules.append(saved)
                }
            }
        }
    }

    @ViewBuilder
    private func conditionalRuleRow(_ rule: ConditionalRule) -> some View {
        HStack(spacing: 0) {
            Text(rule.pattern)
                .font(.callout.monospaced())
                .frame(width: 200, alignment: .leading)
                .lineLimit(1)

            Text(rule.account)
                .font(.callout)
                .frame(minWidth: 200, alignment: .leading)
                .lineLimit(1)

            Spacer()

            Button {
                editingConditionalRule = rule
                showingConditionalForm = true
            } label: {
                Image(systemName: "pencil")
                    .font(.caption)
            }
            .buttonStyle(.plain)

            Button {
                config.conditionalRules.removeAll { $0.id == rule.id }
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(Theme.Status.critical)
            }
            .buttonStyle(.plain)
            .padding(.leading, Theme.Spacing.sm)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xxsPlus)
    }

    // MARK: - Raw Editor

    @ViewBuilder
    private var rawEditorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Raw Editor", systemImage: "doc.text")
                    .font(.headline)

                Spacer()

                Toggle("Show", isOn: $showRawEditor)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            if showRawEditor {
                if let error = rawParseError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(Theme.Status.warning)
                }

                TextEditor(text: $rawText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .border(Color.secondary.opacity(0.3))
                    .onChange(of: rawText) {
                        syncRawToConfig()
                    }
            }
        }
        .padding(Theme.Spacing.mdPlus)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        .onChange(of: showRawEditor) {
            if showRawEditor {
                syncConfigToRaw()
            }
        }
        .onChange(of: config.columnMappings.map(\.assignedField)) {
            if showRawEditor { syncConfigToRaw() }
        }
        .onChange(of: config.conditionalRules) {
            if showRawEditor { syncConfigToRaw() }
        }
        .onChange(of: config.defaultAccount) {
            if showRawEditor { syncConfigToRaw() }
        }
        .onChange(of: config.defaultCurrency) {
            if showRawEditor { syncConfigToRaw() }
        }
        .onChange(of: config.dateFormat) {
            if showRawEditor { syncConfigToRaw() }
        }
    }

    // MARK: - Raw ↔ Config Sync

    private func syncConfigToRaw() {
        rawText = CsvRulesManager.formatRulesFile(config)
        rawParseError = nil
    }

    private func syncRawToConfig() {
        let parsed = CsvRulesManager.parseRulesContent(rawText)
        // Preserve column headers and samples from current config
        var updated = parsed
        for i in updated.columnMappings.indices {
            if i < config.columnMappings.count {
                updated.columnMappings[i].csvColumnHeader = config.columnMappings[i].csvColumnHeader
                updated.columnMappings[i].sampleValue = config.columnMappings[i].sampleValue
            }
        }
        config = updated
        rawParseError = nil
    }
}

// MARK: - Previews

private struct RulesEditorPreviewWrapper: View {
    @State private var config: CsvRulesConfig

    let csv: String
    let accounts: [String]
    let commodities: [String]

    init(config: CsvRulesConfig, csv: String, accounts: [String], commodities: [String]) {
        self._config = State(initialValue: config)
        self.csv = csv
        self.accounts = accounts
        self.commodities = commodities
    }

    var body: some View {
        CsvRulesEditorView(
            config: $config,
            csvContent: csv,
            knownAccounts: accounts,
            knownCommodities: commodities
        )
    }
}

#Preview("Bank CSV — Auto-detected") {
    let csv = """
    Date,Description,Amount,Balance
    2024-01-15,Supermarket Lidl,-45.20,8154.80
    2024-01-14,Salary January,3200.00,8200.00
    2024-01-12,Amazon Prime,-14.99,5000.00
    2024-01-10,Electric Bill,-89.50,5014.99
    """

    let config = CsvRulesConfig(
        name: "ING Bank",
        separator: .comma,
        skipLines: 1,
        dateFormat: "%Y-%m-%d",
        defaultAccount: "assets:bank:checking",
        defaultCurrency: "EUR",
        columnMappings: [
            ColumnMapping(csvColumnIndex: 0, csvColumnHeader: "Date", sampleValue: "2024-01-15", assignedField: .date),
            ColumnMapping(csvColumnIndex: 1, csvColumnHeader: "Description", sampleValue: "Supermarket Lidl", assignedField: .description),
            ColumnMapping(csvColumnIndex: 2, csvColumnHeader: "Amount", sampleValue: "-45.20", assignedField: .amount),
            ColumnMapping(csvColumnIndex: 3, csvColumnHeader: "Balance", sampleValue: "8154.80", assignedField: nil),
        ],
        conditionalRules: [
            ConditionalRule(pattern: "lidl|supermarket", account: "expenses:groceries"),
            ConditionalRule(pattern: "amazon", account: "expenses:shopping"),
        ]
    )

    return RulesEditorPreviewWrapper(
        config: config,
        csv: csv,
        accounts: [
            "assets:bank:checking", "assets:cash",
            "expenses:groceries", "expenses:shopping", "expenses:utilities",
            "income:salary",
        ],
        commodities: ["EUR", "USD"]
    )
    .frame(width: 620, height: 700)
}
