/// CSV rules file management: auto-detection, parsing, formatting, and import.
///
/// Follows the BudgetManager/RecurringManager pattern: an enum with static methods
/// that handle all business logic for CSV import rules files.

import Foundation

enum CsvRulesManager {

    // MARK: - Rules Directory

    /// Rules directory next to the main journal.
    static func rulesDirectory(for journalFile: URL) -> URL {
        journalFile.deletingLastPathComponent().appendingPathComponent("rules")
    }

    /// Ensure the rules directory exists.
    static func ensureRulesDirectory(for journalFile: URL) throws -> URL {
        let dir = rulesDirectory(for: journalFile)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Auto-Detection

    /// Detect the CSV separator by counting candidate characters in the first few lines.
    static func detectSeparator(_ content: String) -> CsvSeparator {
        let lines = content.split(separator: "\n", maxSplits: 5).map(String.init)
        guard !lines.isEmpty else { return .comma }

        let candidates: [CsvSeparator] = [.comma, .semicolon, .tab, .pipe]
        var bestSep = CsvSeparator.comma
        var bestScore = 0

        for sep in candidates {
            let counts = lines.prefix(5).map { line in
                line.filter { String($0) == sep.rawValue }.count
            }
            // A good separator appears consistently across lines
            let minCount = counts.min() ?? 0
            if minCount > 0 && minCount > bestScore {
                bestScore = minCount
                bestSep = sep
            }
        }
        return bestSep
    }

    /// Detect whether the first row is a header (non-numeric, non-date content).
    static func detectHeaderRow(_ content: String, separator: CsvSeparator) -> (hasHeader: Bool, headers: [String]) {
        let lines = content.split(separator: "\n", maxSplits: 1).map(String.init)
        guard let firstLine = lines.first else { return (false, []) }

        let cells = splitCsvLine(firstLine, separator: separator)
        let datePattern = /^\d{1,4}[-\/\.]\d{1,2}[-\/\.]\d{1,4}$/
        let numberPattern = /^-?[\d,.]+$/

        for cell in cells {
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.wholeMatch(of: datePattern) != nil { return (false, genericHeaders(count: cells.count)) }
            if trimmed.count > 1, trimmed.wholeMatch(of: numberPattern) != nil { return (false, genericHeaders(count: cells.count)) }
        }

        return (true, cells.map { $0.trimmingCharacters(in: .whitespaces) })
    }

    /// Detect date format from sample date strings.
    static func detectDateFormat(_ samples: [String]) -> String {
        let formats = [
            "%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y",
            "%d-%m-%Y", "%d.%m.%Y", "%Y/%m/%d",
        ]

        let nonEmpty = samples.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !nonEmpty.isEmpty else { return "%Y-%m-%d" }

        for fmt in formats {
            if nonEmpty.allSatisfy({ tryParseDate($0, format: fmt) }) {
                return fmt
            }
        }
        return "%Y-%m-%d"
    }

    /// Auto-detect column mappings by header name and sample values.
    static func autoMapColumns(headers: [String], sampleRows: [[String]]) -> [ColumnMapping] {
        var mappings = headers.enumerated().map { i, header in
            let sample = sampleRows.first.flatMap { i < $0.count ? $0[i] : nil } ?? ""
            return ColumnMapping(csvColumnIndex: i, csvColumnHeader: header, sampleValue: sample)
        }

        var assigned: Set<String> = []

        // Pass 1: match by header name keywords
        let nameHints: [(field: HledgerField, keywords: [String])] = [
            (.date, ["date", "datum", "data", "valuta", "booking"]),
            (.description, ["description", "desc", "descrizione", "memo", "narrative", "payee", "beneficiary", "details", "reference"]),
            (.amount, ["amount", "importo", "betrag", "sum", "value"]),
            (.amountIn, ["credit", "income", "in", "deposit"]),
            (.amountOut, ["debit", "expense", "out", "withdrawal"]),
        ]

        for i in mappings.indices {
            let headerLower = mappings[i].csvColumnHeader.lowercased()
            for (field, keywords) in nameHints {
                guard !assigned.contains(field.rawValue) else { continue }
                if keywords.contains(where: { headerLower.contains($0) }) {
                    mappings[i].assignedField = field
                    assigned.insert(field.rawValue)
                    break
                }
            }
        }

        // Pass 2: use sample values for unassigned columns
        let datePattern = /\d{1,4}[-\/\.]\d{1,2}[-\/\.]\d{1,4}/
        let numberPattern = /^-?[\d]+[,.]?\d*$/

        for i in mappings.indices where mappings[i].assignedField == nil {
            let samples = sampleRows.compactMap { i < $0.count ? $0[i].trimmingCharacters(in: .whitespaces) : nil }.filter { !$0.isEmpty }
            guard !samples.isEmpty else { continue }

            // Date-like?
            if !assigned.contains(HledgerField.date.rawValue),
               samples.allSatisfy({ $0.wholeMatch(of: datePattern) != nil }) {
                mappings[i].assignedField = .date
                assigned.insert(HledgerField.date.rawValue)
                continue
            }

            // Number-like?
            if !assigned.contains(HledgerField.amount.rawValue),
               samples.allSatisfy({ $0.replacingOccurrences(of: " ", with: "").wholeMatch(of: numberPattern) != nil }) {
                mappings[i].assignedField = .amount
                assigned.insert(HledgerField.amount.rawValue)
                continue
            }

            // Long text → description
            if !assigned.contains(HledgerField.description.rawValue) {
                let avgLen = samples.map(\.count).reduce(0, +) / max(samples.count, 1)
                if avgLen > 10 {
                    mappings[i].assignedField = .description
                    assigned.insert(HledgerField.description.rawValue)
                }
            }
        }

        return mappings
    }

    // MARK: - CSV Parsing

    /// Parse raw CSV content into rows of string arrays.
    static func parseRawCsv(_ content: String, separator: CsvSeparator, skipLines: Int = 0) -> [[String]] {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        return lines.dropFirst(skipLines).map { splitCsvLine($0, separator: separator) }
    }

    /// Split a single CSV line by separator, respecting quoted fields.
    static func splitCsvLine(_ line: String, separator: CsvSeparator) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if String(char) == separator.rawValue && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }

    // MARK: - Rules File I/O

    /// Parse a .rules file into a CsvRulesConfig.
    static func parseRulesFile(url: URL) -> CsvRulesConfig? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return parseRulesContent(content)
    }

    /// Parse rules file text content into a CsvRulesConfig.
    static func parseRulesContent(_ content: String) -> CsvRulesConfig {
        var config = CsvRulesConfig()
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        // Extract display name from first-line comment
        if let first = lines.first?.trimmingCharacters(in: .whitespaces),
           first.hasPrefix(";"),
           let match = first.firstMatch(of: /^;\s*name:\s*(.+)$/) {
            config.name = String(match.1).trimmingCharacters(in: .whitespaces)
        }

        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            if line.isEmpty || line.hasPrefix(";") {
                i += 1
                continue
            }

            if line.hasPrefix("skip") {
                let parts = line.split(separator: " ", maxSplits: 1)
                config.skipLines = parts.count > 1 ? (Int(parts[1]) ?? 1) : 1
                i += 1
                continue
            }

            if line.hasPrefix("separator") {
                let value = String(line.dropFirst("separator".count)).trimmingCharacters(in: .whitespaces)
                config.separator = CsvSeparator(rulesValue: value) ?? .comma
                i += 1
                continue
            }

            if line.hasPrefix("date-format") {
                config.dateFormat = String(line.dropFirst("date-format".count)).trimmingCharacters(in: .whitespaces)
                i += 1
                continue
            }

            if line.hasPrefix("newest-first") {
                i += 1
                continue
            }

            if line.hasPrefix("fields") {
                let fieldsStr = String(line.dropFirst("fields".count)).trimmingCharacters(in: .whitespaces)
                let fieldNames = fieldsStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                config.columnMappings = fieldNames.enumerated().map { idx, name in
                    ColumnMapping(
                        csvColumnIndex: idx,
                        csvColumnHeader: "Col \(idx + 1)",
                        assignedField: HledgerField(rawValue: name)
                    )
                }
                i += 1
                continue
            }

            if line.hasPrefix("account1") {
                config.defaultAccount = String(line.dropFirst("account1".count)).trimmingCharacters(in: .whitespaces)
                i += 1
                continue
            }

            if line.hasPrefix("currency") {
                config.defaultCurrency = String(line.dropFirst("currency".count)).trimmingCharacters(in: .whitespaces)
                i += 1
                continue
            }

            // Conditional rules: "if PATTERN" followed by indented "account2 ACCOUNT"
            if line.hasPrefix("if") {
                let pattern = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                var account = ""
                var comment = ""
                var j = i + 1
                while j < lines.count {
                    let indented = lines[j]
                    guard indented.first?.isWhitespace == true else { break }
                    let trimmed = indented.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("account2") {
                        account = String(trimmed.dropFirst("account2".count)).trimmingCharacters(in: .whitespaces)
                    } else if trimmed.hasPrefix("comment") {
                        comment = String(trimmed.dropFirst("comment".count)).trimmingCharacters(in: .whitespaces)
                    }
                    j += 1
                }
                if !pattern.isEmpty {
                    config.conditionalRules.append(ConditionalRule(pattern: pattern, account: account, comment: comment))
                }
                i = j
                continue
            }

            i += 1
        }

        return config
    }

    /// Format a CsvRulesConfig into hledger rules file text.
    static func formatRulesFile(_ config: CsvRulesConfig) -> String {
        var lines: [String] = []

        // Name comment
        if !config.name.isEmpty {
            lines.append("; name: \(config.name)")
        }

        // Separator
        if config.separator != .comma {
            lines.append("separator \(config.separator.rulesValue)")
        }

        // Skip
        if config.skipLines > 0 {
            lines.append("skip \(config.skipLines)")
        }

        // Date format
        lines.append("date-format \(config.dateFormat)")

        // Fields
        if !config.columnMappings.isEmpty {
            let fieldNames = config.columnMappings.map { $0.assignedField?.rawValue ?? "" }
            lines.append("fields \(fieldNames.joined(separator: ", "))")
        }

        // Currency
        if !config.defaultCurrency.isEmpty {
            lines.append("currency \(config.defaultCurrency)")
        }

        // Account1
        if !config.defaultAccount.isEmpty {
            lines.append("account1 \(config.defaultAccount)")
        }

        // Conditional rules
        for rule in config.conditionalRules {
            lines.append("")
            lines.append("if \(rule.pattern)")
            if !rule.account.isEmpty {
                lines.append("  account2 \(rule.account)")
            }
            if !rule.comment.isEmpty {
                lines.append("  comment \(rule.comment)")
            }
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    /// Write a rules file to disk.
    static func writeRulesFile(_ config: CsvRulesConfig, to url: URL) throws {
        let content = formatRulesFile(config)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Rules Discovery

    /// Find companion .rules file for a CSV (e.g., bank.csv → bank.csv.rules).
    static func findCompanionRules(for csvFile: URL) -> URL? {
        let companion = csvFile.appendingPathExtension("rules")
        return FileManager.default.fileExists(atPath: companion.path) ? companion : nil
    }

    /// List all .rules files in a directory.
    static func listRulesFiles(in directory: URL) -> [RulesFileInfo] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return [] }

        return contents
            .filter { $0.pathExtension == "rules" }
            .compactMap { url -> RulesFileInfo? in
                let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                let config = parseRulesFile(url: url)
                return RulesFileInfo(
                    url: url,
                    name: config?.name ?? url.deletingPathExtension().lastPathComponent,
                    account1: config?.defaultAccount ?? "",
                    lastModified: attrs?.contentModificationDate
                )
            }
            .sorted { ($0.name) < ($1.name) }
    }

    /// List rules files from both the journal directory and the rules subdirectory.
    static func listAllRulesFiles(for journalFile: URL) -> [RulesFileInfo] {
        let journalDir = journalFile.deletingLastPathComponent()
        let rulesDir = rulesDirectory(for: journalFile)

        var results = listRulesFiles(in: journalDir)
        if rulesDir != journalDir, FileManager.default.fileExists(atPath: rulesDir.path) {
            results.append(contentsOf: listRulesFiles(in: rulesDir))
        }
        return results.sorted { $0.name < $1.name }
    }

    // MARK: - Duplicate Detection

    /// Compare preview transactions against existing journal transactions.
    static func detectDuplicates(
        preview: [CsvPreviewTransaction],
        existing: [Transaction]
    ) -> [CsvPreviewTransaction] {
        let existingSet = Set(existing.map { txn -> String in
            let amount = txn.postings.first?.amounts.first.map { "\($0.quantity)" } ?? ""
            return "\(txn.date)|\(txn.description.lowercased())|\(amount)"
        })

        return preview.map { txn in
            var updated = txn
            let key = "\(txn.date)|\(txn.description.lowercased())|\(txn.amount)"
            updated.isDuplicate = existingSet.contains(key)
            updated.isSelected = !updated.isDuplicate
            return updated
        }
    }

    // MARK: - Helpers

    private static func genericHeaders(count: Int) -> [String] {
        (1...count).map { "Col \($0)" }
    }

    private static func tryParseDate(_ string: String, format: String) -> Bool {
        // Check separator consistency: if format uses "/" the string must too, etc.
        for sep in ["/", "-", "."] where format.contains(sep) {
            if !string.contains(sep) { return false }
        }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.isLenient = false
        df.dateFormat = format.replacingOccurrences(of: "%Y", with: "yyyy")
            .replacingOccurrences(of: "%m", with: "MM")
            .replacingOccurrences(of: "%d", with: "dd")
        return df.date(from: string) != nil
    }
}
