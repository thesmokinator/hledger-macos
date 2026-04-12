/// Main CSV Import Wizard container.
///
/// Three-tab wizard: CSV Preview → Rules Editor → Import Preview.
/// Manages all state and coordinates between tabs.

import SwiftUI
import UniformTypeIdentifiers

struct CsvImportSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0

    // CSV state
    @State private var csvFileURL: URL?
    @State private var csvContent = ""

    // Rules state
    @State private var config = CsvRulesConfig()
    @State private var rulesFileURL: URL?
    @State private var rulesFiles: [RulesFileInfo] = []
    @State private var companionRules: URL?

    // Preview state
    @State private var previewTransactions: [CsvPreviewTransaction] = []
    @State private var isParsing = false
    @State private var parseError: String?

    // Import state
    @State private var isImporting = false
    @State private var importResult: String?

    // Accounts and commodities for autocomplete
    @State private var knownAccounts: [String] = []
    @State private var knownCommodities: [String] = []

    // MARK: - Validation

    private var validationErrors: [String] {
        var errors: [String] = []
        if config.columnMappings.isEmpty {
            errors.append("No column mappings defined")
        } else {
            if !config.columnMappings.contains(where: { $0.assignedField == .date }) {
                errors.append("No date column mapped")
            }
            let hasAmount = config.columnMappings.contains { $0.assignedField == .amount }
            let hasAmountIn = config.columnMappings.contains { $0.assignedField == .amountIn }
            if !hasAmount && !hasAmountIn {
                errors.append("No amount column mapped")
            }
        }
        if config.defaultAccount.isEmpty {
            errors.append("No account configured")
        }
        return errors
    }

    private var isReadyToImport: Bool {
        selectedTab == 2 && !previewTransactions.filter(\.isSelected).isEmpty && validationErrors.isEmpty && !isParsing && !isImporting
    }

    private var selectedCount: Int {
        previewTransactions.filter(\.isSelected).count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Import CSV")
                    .font(.title2.bold())

                Spacer()

                if let url = csvFileURL {
                    Text(url.lastPathComponent)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Button("Change File") {
                        pickCsvFile()
                    }
                    .font(.callout)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.sm)

            if csvContent.isEmpty {
                noFileView
            } else {
                TabView(selection: $selectedTab) {
                    CsvRawPreviewTab(
                        csvContent: csvContent,
                        config: $config,
                        rulesFileURL: $rulesFileURL,
                        rulesFiles: rulesFiles,
                        companionRules: companionRules
                    )
                    .tabItem { Label("1. CSV Preview", systemImage: "tablecells") }
                    .tag(0)

                    CsvRulesEditorView(
                        config: $config,
                        csvContent: csvContent,
                        knownAccounts: knownAccounts,
                        knownCommodities: knownCommodities
                    )
                    .tabItem { Label("2. Rules Editor", systemImage: "doc.text") }
                    .tag(1)

                    CsvTransactionPreviewTab(
                        previewTransactions: $previewTransactions,
                        isLoading: isParsing,
                        errorMessage: parseError
                    )
                    .tabItem { Label("3. Import", systemImage: "square.and.arrow.down") }
                    .tag(2)
                }
                .onChange(of: selectedTab) {
                    if selectedTab == 2 {
                        Task { await parsePreview() }
                    }
                }
            }

            Divider()

            // Bottom bar — consistent with other dialogs
            HStack {
                if let result = importResult {
                    Label(result, systemImage: "checkmark.circle")
                        .font(.callout)
                        .foregroundStyle(Theme.Status.good)
                } else if !validationErrors.isEmpty && selectedTab == 2 {
                    Label(validationErrors.first!, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(Theme.Status.warning)
                } else if selectedTab == 2 && selectedCount > 0 {
                    Text("\(selectedCount) transaction\(selectedCount == 1 ? "" : "s") selected")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Import") {
                    Task { await performImport() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isReadyToImport)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.md)
        }
        .frame(width: 760, height: 660)
        .task { await loadAutocompleteData() }
        .onAppear {
            if csvContent.isEmpty {
                pickCsvFile()
            }
        }
    }

    // MARK: - No File View

    @ViewBuilder
    private var noFileView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Select a CSV file to import")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button("Choose CSV File") {
                pickCsvFile()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - File Picker

    private func pickCsvFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType.commaSeparatedText,
            UTType(filenameExtension: "csv") ?? .commaSeparatedText,
            UTType.tabSeparatedText,
            UTType(filenameExtension: "tsv") ?? .tabSeparatedText,
            UTType.plainText,
        ].compactMap { $0 }
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a CSV file to import"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            csvContent = try String(contentsOf: url, encoding: .utf8)
            csvFileURL = url
            companionRules = CsvRulesManager.findCompanionRules(for: url)

            if let journal = appState.activeBackend?.journalFile {
                rulesFiles = CsvRulesManager.listAllRulesFiles(for: journal)
            }

            config = CsvRulesConfig()
            previewTransactions = []
            parseError = nil
            importResult = nil
            selectedTab = 0
        } catch {
            parseError = "Could not read file: \(error.localizedDescription)"
        }
    }

    // MARK: - Autocomplete Data

    private func loadAutocompleteData() async {
        guard let backend = appState.activeBackend else { return }
        knownAccounts = (try? await backend.loadAccounts()) ?? []
        knownCommodities = (try? await backend.loadCommodities()) ?? []
    }

    // MARK: - Parse Preview

    private func parsePreview() async {
        guard let backend = appState.activeBackend, !csvContent.isEmpty else { return }
        guard validationErrors.isEmpty else {
            parseError = validationErrors.joined(separator: ". ")
            return
        }

        isParsing = true
        parseError = nil
        previewTransactions = []

        do {
            let tempRules = FileManager.default.temporaryDirectory
                .appendingPathComponent("hledger-import-\(UUID().uuidString).rules")
            try CsvRulesManager.writeRulesFile(config, to: tempRules)
            defer { try? FileManager.default.removeItem(at: tempRules) }

            let csvFile = csvFileURL ?? {
                let temp = FileManager.default.temporaryDirectory
                    .appendingPathComponent("import-\(UUID().uuidString).csv")
                try? csvContent.write(to: temp, atomically: true, encoding: .utf8)
                return temp
            }()

            let transactions = try await backend.parseCsvImport(csvFile: csvFile, rulesFile: tempRules)

            var preview = transactions.map { txn -> CsvPreviewTransaction in
                let amount = txn.postings.first?.amounts.first.map { $0.displayFormatted() } ?? ""
                let account1 = txn.postings.first?.account ?? ""
                let account2 = txn.postings.count > 1 ? txn.postings[1].account : ""
                return CsvPreviewTransaction(
                    date: txn.date,
                    description: txn.description,
                    amount: amount,
                    account1: account1,
                    account2: account2
                )
            }

            let existing = try await backend.loadTransactions(query: nil, reversed: false)
            preview = CsvRulesManager.detectDuplicates(preview: preview, existing: existing)

            previewTransactions = preview
        } catch {
            parseError = error.localizedDescription
        }

        isParsing = false
    }

    // MARK: - Import

    private func performImport() async {
        guard let backend = appState.activeBackend else { return }

        let toImport = previewTransactions.filter(\.isSelected)
        guard !toImport.isEmpty else { return }

        isImporting = true

        do {
            let tempRules = FileManager.default.temporaryDirectory
                .appendingPathComponent("hledger-import-\(UUID().uuidString).rules")
            try CsvRulesManager.writeRulesFile(config, to: tempRules)
            defer { try? FileManager.default.removeItem(at: tempRules) }

            let csvFile = csvFileURL ?? URL(fileURLWithPath: "/dev/null")
            let allTransactions = try await backend.parseCsvImport(csvFile: csvFile, rulesFile: tempRules)

            let selectedDates = Set(toImport.map { "\($0.date)|\($0.description)" })
            var imported = 0
            for txn in allTransactions {
                let key = "\(txn.date)|\(txn.description)"
                if selectedDates.contains(key) {
                    try await backend.appendTransaction(txn)
                    imported += 1
                }
            }

            importResult = "Imported \(imported) transaction\(imported == 1 ? "" : "s")"

            if rulesFileURL == nil, let journal = backend.journalFile as URL? {
                let rulesDir = try CsvRulesManager.ensureRulesDirectory(for: journal)
                let fileName = config.name.isEmpty ? "import" : config.name.lowercased().replacingOccurrences(of: " ", with: "-")
                let targetURL = rulesDir.appendingPathComponent("\(fileName).rules")
                try CsvRulesManager.writeRulesFile(config, to: targetURL)
            }

            await appState.reloadAfterWrite()
        } catch {
            parseError = "Import failed: \(error.localizedDescription)"
        }

        isImporting = false
    }
}
