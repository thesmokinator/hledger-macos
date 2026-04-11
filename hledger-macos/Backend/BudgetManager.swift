/// Budget file management: read/write periodic transactions in budget.journal.
///
/// Ported from hledger-textual/budget.py.

import Foundation

enum BudgetManager {
    static let budgetFilename = "budget.journal"

    // MARK: - File Path

    /// Path to budget.journal next to the main journal.
    static func budgetPath(for journalFile: URL) -> URL {
        journalFile.deletingLastPathComponent().appendingPathComponent(budgetFilename)
    }

    // MARK: - Ensure File Exists

    /// Create budget.journal if missing and add include directive to main journal.
    static func ensureBudgetFile(journalFile: URL) throws {
        let budgetFile = budgetPath(for: journalFile)

        if !FileManager.default.fileExists(atPath: budgetFile.path) {
            try "".write(to: budgetFile, atomically: true, encoding: .utf8)
        }

        var journalText = try String(contentsOf: journalFile, encoding: .utf8)
        let includePattern = /^\s*include\s+budget\.journal\s*$/
        let hasInclude = journalText.split(separator: "\n").contains { line in
            line.wholeMatch(of: includePattern) != nil
        }

        if !hasInclude {
            let includeLine = "include \(budgetFilename)\n\n"
            journalText = includeLine + journalText
            try journalText.write(to: journalFile, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Parse Rules

    /// Parse budget rules from budget.journal.
    static func parseRules(budgetPath: URL) -> [BudgetRule] {
        guard FileManager.default.fileExists(atPath: budgetPath.path),
              let content = try? String(contentsOf: budgetPath, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        var rules: [BudgetRule] = []
        var inPeriodic = false
        let periodicPattern = /^~\s+\S/
        let postingPattern = /^\s{4,}(\S.+?)\s{2,}(\S+)\s*(?:;\s*category:\s*(.+?))?\s*$/
        let balancingPattern = /^\s{4,}Assets:Budget\s*$/

        for line in content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.firstMatch(of: periodicPattern) != nil {
                inPeriodic = true
                continue
            }

            if inPeriodic {
                if !line.isEmpty && !line.first!.isWhitespace {
                    break
                }
                if line.firstMatch(of: balancingPattern) != nil { continue }
                if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }

                if let match = line.firstMatch(of: postingPattern) {
                    let account = String(match.1).trimmingCharacters(in: .whitespaces)
                    let amountStr = String(match.2).trimmingCharacters(in: .whitespaces)
                    let category = match.3.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
                    // Use PostingAmountParser so the loaded Amount inherits its
                    // full style (decimalMark, digitGroupSeparator, precision)
                    // from the literal — same path as form input. See #129.
                    if let amount = PostingAmountParser.parseSimple(amountStr) {
                        rules.append(BudgetRule(
                            account: account,
                            amount: amount,
                            category: category
                        ))
                    }
                }
            }
        }

        return rules
    }

    // MARK: - Format Rules

    /// Format budget rules into budget.journal content.
    static func formatRules(_ rules: [BudgetRule]) -> String {
        guard !rules.isEmpty else { return "" }

        var lines = ["~ monthly"]
        let maxAccount = rules.map(\.account.count).max() ?? 40
        let accountWidth = max(maxAccount + 4, 40)

        for rule in rules {
            let amountStr = rule.amount.formatted()
            let padding = String(repeating: " ", count: accountWidth - rule.account.count)
            if !rule.category.isEmpty {
                lines.append("    \(rule.account)\(padding)\(amountStr)  ; category: \(rule.category)")
            } else {
                lines.append("    \(rule.account)\(padding)\(amountStr)")
            }
        }

        lines.append("    Assets:Budget")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    // MARK: - Write Rules

    /// Write budget rules with backup/validate/restore.
    static func writeRules(_ rules: [BudgetRule], budgetPath: URL, journalFile: URL, validator: any AccountingBackend) async throws {
        let backup = budgetPath.appendingPathExtension("bak")
        if FileManager.default.fileExists(atPath: budgetPath.path) {
            try FileManager.default.copyItem(at: budgetPath, to: backup)
        }

        do {
            let content = formatRules(rules)
            try content.write(to: budgetPath, atomically: true, encoding: .utf8)
            try await validator.validateJournal()
            try? FileManager.default.removeItem(at: backup)
        } catch {
            if FileManager.default.fileExists(atPath: backup.path) {
                try? FileManager.default.removeItem(at: budgetPath)
                try? FileManager.default.moveItem(at: backup, to: budgetPath)
            }
            try? FileManager.default.removeItem(at: backup)
            throw BackendError.journalValidationFailed("Budget validation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - CRUD

    /// Add a new budget rule.
    static func addRule(_ rule: BudgetRule, journalFile: URL, validator: any AccountingBackend) async throws {
        let path = budgetPath(for: journalFile)
        try ensureBudgetFile(journalFile: journalFile)
        var rules = parseRules(budgetPath: path)
        if rules.contains(where: { $0.account == rule.account }) {
            throw BackendError.commandFailed("Budget rule already exists for \(rule.account)")
        }
        rules.append(rule)
        try await writeRules(rules, budgetPath: path, journalFile: journalFile, validator: validator)
    }

    /// Update an existing budget rule.
    static func updateRule(oldAccount: String, newRule: BudgetRule, journalFile: URL, validator: any AccountingBackend) async throws {
        let path = budgetPath(for: journalFile)
        var rules = parseRules(budgetPath: path)
        guard let index = rules.firstIndex(where: { $0.account == oldAccount }) else {
            throw BackendError.commandFailed("No budget rule found for \(oldAccount)")
        }
        rules[index] = newRule
        try await writeRules(rules, budgetPath: path, journalFile: journalFile, validator: validator)
    }

    /// Delete a budget rule by account name.
    static func deleteRule(account: String, journalFile: URL, validator: any AccountingBackend) async throws {
        let path = budgetPath(for: journalFile)
        var rules = parseRules(budgetPath: path)
        let count = rules.count
        rules.removeAll { $0.account == account }
        if rules.count == count {
            throw BackendError.commandFailed("No budget rule found for \(account)")
        }
        try await writeRules(rules, budgetPath: path, journalFile: journalFile, validator: validator)
    }
}
