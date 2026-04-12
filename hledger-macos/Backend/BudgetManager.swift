/// Budget file management: read/write periodic transactions in budget.journal.
///
/// Ported from hledger-textual/budget.py.
///
/// `BudgetRuleFile` implements the `RuleFile` protocol with the budget-specific
/// parse/format logic and key (`account`).  All shared file workflow is handled
/// by `RuleFileManager<BudgetRuleFile>`.
/// `BudgetManager` is a thin wrapper that preserves the existing public API.

import Foundation

// MARK: - BudgetRuleFile

enum BudgetRuleFile: RuleFile {
    typealias Rule = BudgetRule
    typealias Key = String

    static let filename = "budget.journal"

    static func key(of rule: BudgetRule) -> String { rule.account }

    static func duplicateError(_ key: String) -> BackendError {
        .commandFailed("Budget rule already exists for \(key)")
    }

    static func notFoundError(_ key: String) -> BackendError {
        .commandFailed("No budget rule found for \(key)")
    }

    // MARK: Parse

    static func parseRules(from content: String) -> [BudgetRule] {
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
                if !line.isEmpty && !line.first!.isWhitespace { break }
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
                        rules.append(BudgetRule(account: account, amount: amount, category: category))
                    }
                }
            }
        }

        return rules
    }

    // MARK: Format

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
}

// MARK: - BudgetManager (public API wrapper)

/// Thin wrapper around `RuleFileManager<BudgetRuleFile>` that preserves the
/// original `BudgetManager` call surface used by views and tests.
enum BudgetManager {

    // MARK: File path

    static func budgetPath(for journalFile: URL) -> URL {
        RuleFileManager<BudgetRuleFile>.filePath(for: journalFile)
    }

    // MARK: Ensure file exists

    static func ensureBudgetFile(journalFile: URL) throws {
        try RuleFileManager<BudgetRuleFile>.ensureFile(journalFile: journalFile)
    }

    // MARK: Parse / format

    static func parseRules(budgetPath: URL) -> [BudgetRule] {
        RuleFileManager<BudgetRuleFile>.parseRules(at: budgetPath)
    }

    static func formatRules(_ rules: [BudgetRule]) -> String {
        RuleFileManager<BudgetRuleFile>.formatRules(rules)
    }

    // MARK: Write

    static func writeRules(
        _ rules: [BudgetRule],
        budgetPath: URL,
        journalFile: URL,
        validator: any AccountingBackend
    ) async throws {
        try await RuleFileManager<BudgetRuleFile>.writeRules(
            rules, to: budgetPath, journalFile: journalFile, validator: validator
        )
    }

    // MARK: CRUD

    static func addRule(_ rule: BudgetRule, journalFile: URL, validator: any AccountingBackend) async throws {
        try await RuleFileManager<BudgetRuleFile>.addRule(rule, journalFile: journalFile, validator: validator)
    }

    static func updateRule(oldAccount: String, newRule: BudgetRule, journalFile: URL, validator: any AccountingBackend) async throws {
        try await RuleFileManager<BudgetRuleFile>.updateRule(key: oldAccount, newRule: newRule, journalFile: journalFile, validator: validator)
    }

    static func deleteRule(account: String, journalFile: URL, validator: any AccountingBackend) async throws {
        try await RuleFileManager<BudgetRuleFile>.deleteRule(key: account, journalFile: journalFile, validator: validator)
    }
}
