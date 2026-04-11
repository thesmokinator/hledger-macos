/// Standalone rules file manager: list, create, edit, and delete CSV rules files.

import SwiftUI

struct RulesManagerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var rulesFiles: [RulesFileInfo] = []
    @State private var selectedRule: RulesFileInfo?
    @State private var editingConfig: CsvRulesConfig?
    @State private var editingURL: URL?
    @State private var showingEditor = false
    @State private var showingDeleteConfirm = false
    @State private var ruleToDelete: RulesFileInfo?
    @State private var errorMessage: String?

    @State private var knownAccounts: [String] = []
    @State private var knownCommodities: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text("Rules Manager")
                    .font(.title2.bold())
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // List
            if rulesFiles.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No rules files found")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Rules files are stored in the rules/ directory next to your journal.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
            } else {
                List(selection: $selectedRule) {
                    ForEach(rulesFiles) { info in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(info.name)
                                    .font(.callout.weight(.medium))
                                if !info.account1.isEmpty {
                                    Text(info.account1)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if let date = info.lastModified {
                                Text(date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .tag(info)
                        .contextMenu {
                            Button("Edit") { editRule(info) }
                            Button("Delete", role: .destructive) {
                                ruleToDelete = info
                                showingDeleteConfirm = true
                            }
                        }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }

                Spacer()

                Button("New Rule") {
                    createNewRule()
                }

                if selectedRule != nil {
                    Button("Edit") {
                        if let selected = selectedRule { editRule(selected) }
                    }

                    Button("Delete", role: .destructive) {
                        ruleToDelete = selectedRule
                        showingDeleteConfirm = true
                    }
                }

                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 560, height: 420)
        .task { await loadData() }
        .sheet(isPresented: $showingEditor) {
            if let config = editingConfig {
                RulesEditorSheet(
                    config: config,
                    rulesURL: editingURL,
                    knownAccounts: knownAccounts,
                    knownCommodities: knownCommodities,
                    onSave: { savedConfig, url in
                        do {
                            try CsvRulesManager.writeRulesFile(savedConfig, to: url)
                            refreshList()
                        } catch {
                            errorMessage = "Failed to save: \(error.localizedDescription)"
                        }
                    }
                )
            }
        }
        .confirmDeleteAlert(
            isPresented: $showingDeleteConfirm,
            itemName: "Rules File",
            message: ruleToDelete.map { "Delete \"\($0.name)\"? This cannot be undone." } ?? "",
            onConfirm: { performDelete() }
        )
    }

    // MARK: - Data

    private func loadData() async {
        guard let backend = appState.activeBackend else { return }
        knownAccounts = (try? await backend.loadAccounts()) ?? []
        knownCommodities = (try? await backend.loadCommodities()) ?? []
        refreshList()
    }

    private func refreshList() {
        guard let journal = appState.activeBackend?.journalFile else { return }
        rulesFiles = CsvRulesManager.listAllRulesFiles(for: journal)
    }

    // MARK: - Actions

    private func createNewRule() {
        guard let journal = appState.activeBackend?.journalFile else { return }
        let rulesDir = (try? CsvRulesManager.ensureRulesDirectory(for: journal)) ?? CsvRulesManager.rulesDirectory(for: journal)
        let newURL = rulesDir.appendingPathComponent("new-rules.rules")
        editingConfig = CsvRulesConfig()
        editingURL = newURL
        showingEditor = true
    }

    private func editRule(_ info: RulesFileInfo) {
        if let config = CsvRulesManager.parseRulesFile(url: info.url) {
            editingConfig = config
            editingURL = info.url
            showingEditor = true
        }
    }

    private func performDelete() {
        guard let rule = ruleToDelete else { return }
        do {
            try FileManager.default.removeItem(at: rule.url)
            refreshList()
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
        ruleToDelete = nil
    }
}

// MARK: - Rules Editor Sheet Wrapper

private struct RulesEditorSheet: View {
    @State var config: CsvRulesConfig
    let rulesURL: URL?
    let knownAccounts: [String]
    let knownCommodities: [String]
    let onSave: (CsvRulesConfig, URL) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(config.name.isEmpty ? "New Rules File" : config.name)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            CsvRulesEditorView(
                config: $config,
                csvContent: "",
                knownAccounts: knownAccounts,
                knownCommodities: knownCommodities
            )

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    if let url = rulesURL {
                        onSave(config, url)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 640, height: 580)
    }
}
