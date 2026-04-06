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
                columnMappingSection
                settingsSection
                conditionalRulesSection
                rawEditorSection
            }
            .padding(20)
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
                        .frame(width: 140, alignment: .leading)
                    Text("Sample")
                        .frame(width: 180, alignment: .leading)
                    Text("Assign to")
                        .frame(minWidth: 140, alignment: .leading)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

                ForEach(config.columnMappings.indices, id: \.self) { index in
                    columnMappingRow(index: index)
                }
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func columnMappingRow(index: Int) -> some View {
        HStack(spacing: 0) {
            Text(config.columnMappings[index].csvColumnHeader)
                .font(.callout)
                .frame(width: 140, alignment: .leading)
                .lineLimit(1)

            Text(config.columnMappings[index].sampleValue)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 180, alignment: .leading)
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
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
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
                    Picker("", selection: $config.dateFormat) {
                        Text("YYYY-MM-DD").tag("%Y-%m-%d")
                        Text("DD/MM/YYYY").tag("%d/%m/%Y")
                        Text("MM/DD/YYYY").tag("%m/%d/%Y")
                        Text("DD-MM-YYYY").tag("%d-%m-%Y")
                        Text("DD.MM.YYYY").tag("%d.%m.%Y")
                        Text("YYYY/MM/DD").tag("%Y/%m/%d")
                    }
                    .labelsHidden()
                }

                FormRow("Separator:", labelWidth: 100) {
                    Picker("", selection: $config.separator) {
                        ForEach(CsvSeparator.allCases) { sep in
                            Text(sep.displayName).tag(sep)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }

                FormRow("Skip rows:", labelWidth: 100) {
                    Stepper(value: $config.skipLines, in: 0...10) {
                        Text("\(config.skipLines)")
                            .font(.callout.monospaced())
                    }
                    .frame(width: 120)
                }
            }
        }
        .padding(14)
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
                .padding(.horizontal, 8)

                ForEach(config.conditionalRules) { rule in
                    conditionalRuleRow(rule)
                }
            }
        }
        .padding(14)
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
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
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
                        .foregroundStyle(.orange)
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
        .padding(14)
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
