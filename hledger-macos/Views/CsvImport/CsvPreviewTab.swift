/// Tab 1 of the CSV Import Wizard: raw CSV preview with auto-detection.
///
/// Shows the CSV data in a table, displays detected separator/headers,
/// and lets the user select or create a rules file.

import SwiftUI

struct CsvPreviewTab: View {
    let csvContent: String
    @Binding var config: CsvRulesConfig
    @Binding var rulesFileURL: URL?
    let rulesFiles: [RulesFileInfo]
    let companionRules: URL?

    @State private var selectedRulesOption: RulesOption = .createNew

    private enum RulesOption: Hashable {
        case companion
        case existing(URL)
        case createNew
    }

    /// Parsed rows for the preview table.
    private var previewRows: [[String]] {
        let rows = CsvRulesManager.parseRawCsv(csvContent, separator: config.separator)
        return Array(rows.prefix(20))
    }

    /// Column count from the first row.
    private var columnCount: Int {
        previewRows.first?.count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            detectionInfo
            rulesSelector
            csvTable
        }
        .padding(16)
        .onAppear { runAutoDetection() }
    }

    // MARK: - Detection Info

    @ViewBuilder
    private var detectionInfo: some View {
        HStack(spacing: 20) {
            Label {
                Text("Separator: **\(config.separator.displayName)**")
            } icon: {
                Image(systemName: "arrow.left.and.right")
                    .foregroundStyle(.blue)
            }

            Label {
                Text("Columns: **\(columnCount)**")
            } icon: {
                Image(systemName: "tablecells")
                    .foregroundStyle(.blue)
            }

            Label {
                Text("Rows: **\(max(previewRows.count - config.skipLines, 0))**")
            } icon: {
                Image(systemName: "list.number")
                    .foregroundStyle(.blue)
            }

            Spacer()
        }
        .font(.callout)
    }

    // MARK: - Rules Selector

    @ViewBuilder
    private var rulesSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rules File")
                .font(.headline)

            Picker("", selection: $selectedRulesOption) {
                if companionRules != nil {
                    Text("Use companion rules file")
                        .tag(RulesOption.companion)
                }

                ForEach(rulesFiles) { info in
                    Text("\(info.name) (\(info.account1.isEmpty ? "no account" : info.account1))")
                        .tag(RulesOption.existing(info.url))
                }

                Text("Create new rules")
                    .tag(RulesOption.createNew)
            }
            .labelsHidden()
            .onChange(of: selectedRulesOption) {
                applyRulesSelection()
            }
        }
    }

    // MARK: - CSV Table

    @ViewBuilder
    private var csvTable: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CSV Preview")
                .font(.headline)

            if previewRows.isEmpty {
                Text("No data to preview.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header row (first row or generated)
                        if let firstRow = previewRows.first {
                            HStack(spacing: 0) {
                                ForEach(firstRow.indices, id: \.self) { col in
                                    Text(firstRow[col].trimmingCharacters(in: .whitespaces))
                                        .font(.caption.weight(.semibold))
                                        .frame(width: 150, alignment: .leading)
                                        .lineLimit(1)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 6)
                                }
                            }
                            .background(Color.accentColor.opacity(0.1))

                            Divider()
                        }

                        // Data rows
                        ForEach(Array(previewRows.dropFirst().enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 0) {
                                ForEach(row.indices, id: \.self) { col in
                                    Text(row[col].trimmingCharacters(in: .whitespaces))
                                        .font(.caption.monospaced())
                                        .frame(width: 150, alignment: .leading)
                                        .lineLimit(1)
                                        .padding(.vertical, 3)
                                        .padding(.horizontal, 6)
                                }
                            }
                        }
                    }
                }
                .border(Color.secondary.opacity(0.2))
            }
        }
    }

    // MARK: - Logic

    private func runAutoDetection() {
        let separator = CsvRulesManager.detectSeparator(csvContent)
        let (hasHeader, headers) = CsvRulesManager.detectHeaderRow(csvContent, separator: separator)
        let dataRows = CsvRulesManager.parseRawCsv(csvContent, separator: separator, skipLines: hasHeader ? 1 : 0)
        let sampleRows = Array(dataRows.prefix(5))

        // Detect date format from the first column that looks like dates
        let mappings = CsvRulesManager.autoMapColumns(headers: headers, sampleRows: sampleRows)
        let dateColIdx = mappings.firstIndex { $0.assignedField == .date }
        let dateSamples = dateColIdx.map { idx in sampleRows.compactMap { idx < $0.count ? $0[idx] : nil } } ?? []
        let dateFormat = CsvRulesManager.detectDateFormat(dateSamples)

        config.separator = separator
        config.skipLines = hasHeader ? 1 : 0
        config.dateFormat = dateFormat
        config.columnMappings = mappings

        // Auto-select companion rules if available
        if companionRules != nil {
            selectedRulesOption = .companion
        }
        applyRulesSelection()
    }

    private func applyRulesSelection() {
        switch selectedRulesOption {
        case .companion:
            if let url = companionRules, let parsed = CsvRulesManager.parseRulesFile(url: url) {
                rulesFileURL = url
                // Merge parsed rules into config, keeping auto-detected column info
                config.name = parsed.name
                config.defaultAccount = parsed.defaultAccount
                config.defaultCurrency = parsed.defaultCurrency
                config.conditionalRules = parsed.conditionalRules
                if !parsed.dateFormat.isEmpty { config.dateFormat = parsed.dateFormat }
            }
        case .existing(let url):
            if let parsed = CsvRulesManager.parseRulesFile(url: url) {
                rulesFileURL = url
                config.name = parsed.name
                config.defaultAccount = parsed.defaultAccount
                config.defaultCurrency = parsed.defaultCurrency
                config.conditionalRules = parsed.conditionalRules
                if !parsed.dateFormat.isEmpty { config.dateFormat = parsed.dateFormat }
            }
        case .createNew:
            rulesFileURL = nil
        }
    }
}
