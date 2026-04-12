/// Recurring transactions file management: read/write periodic rules in recurring.journal.
///
/// Ported from hledger-textual/recurring.py.
///
/// `RecurringRuleFile` implements the `RuleFile` protocol with the recurring-specific
/// parse/format logic and key (`ruleId`).  All shared file workflow is handled
/// by `RuleFileManager<RecurringRuleFile>`.
/// `RecurringManager` is a thin wrapper that preserves the existing public API
/// and also provides the transaction-generation helpers unique to recurring rules.

import Foundation

// MARK: - RecurringRuleFile

enum RecurringRuleFile: RuleFile {
    typealias Rule = RecurringRule
    typealias Key = String

    static let filename = "recurring.journal"

    static func key(of rule: RecurringRule) -> String { rule.ruleId }

    static func duplicateError(_ key: String) -> BackendError {
        .commandFailed("Recurring rule already exists with id: \(key)")
    }

    static func notFoundError(_ key: String) -> BackendError {
        .commandFailed("No recurring rule found with id: \(key)")
    }

    // MARK: Parse

    static func parseRules(from content: String) -> [RecurringRule] {
        let headerPattern = /^~\s+(\S+)(?:\s+from\s+(\d{4}-\d{2}-\d{2}))?(?:\s+to\s+(\d{4}-\d{2}-\d{2}))?\s*(?:;\s*rule-id:(\S+)(?:\s+(.+))?)?\s*$/
        let postingPattern = /^\s{4,}(\S.+?)\s{2,}(\S+)\s*$/

        var rules: [RecurringRule] = []
        var currentHeader: (periodExpr: String, startDate: String?, endDate: String?, ruleId: String, description: String)?
        var currentPostings: [Posting] = []

        func flush() {
            guard let header = currentHeader, !header.ruleId.isEmpty else { return }
            rules.append(RecurringRule(
                ruleId: header.ruleId,
                periodExpr: header.periodExpr,
                description: header.description,
                postings: currentPostings,
                startDate: header.startDate,
                endDate: header.endDate
            ))
        }

        for line in content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if let match = line.firstMatch(of: headerPattern) {
                flush()
                currentPostings = []
                currentHeader = (
                    periodExpr: String(match.1),
                    startDate: match.2.map(String.init),
                    endDate: match.3.map(String.init),
                    ruleId: match.4.map(String.init) ?? "",
                    description: (match.5.map(String.init) ?? "").trimmingCharacters(in: .whitespaces)
                )
                continue
            }

            if currentHeader != nil {
                if !line.isEmpty && !line.first!.isWhitespace {
                    flush()
                    currentHeader = nil
                    currentPostings = []
                    continue
                }

                if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }

                if let match = line.firstMatch(of: postingPattern) {
                    let account = String(match.1).trimmingCharacters(in: .whitespaces)
                    let amountStr = String(match.2).trimmingCharacters(in: .whitespaces)
                    // Use PostingAmountParser so the loaded Amount inherits its
                    // full style (decimalMark, digitGroupSeparator, precision)
                    // from the literal — same path as form input. See #129.
                    if let amount = PostingAmountParser.parseSimple(amountStr) {
                        currentPostings.append(Posting(account: account, amounts: [amount]))
                    } else {
                        currentPostings.append(Posting(account: account))
                    }
                } else {
                    let account = line.trimmingCharacters(in: .whitespaces)
                    if !account.isEmpty {
                        currentPostings.append(Posting(account: account))
                    }
                }
            }
        }

        flush()
        return rules
    }

    // MARK: Format

    static func formatRules(_ rules: [RecurringRule]) -> String {
        guard !rules.isEmpty else { return "" }

        var blocks: [String] = []

        for rule in rules {
            var header = "~ \(rule.periodExpr)"
            if let start = rule.startDate, !start.isEmpty { header += " from \(start)" }
            if let end = rule.endDate, !end.isEmpty { header += " to \(end)" }

            var commentParts = ["rule-id:\(rule.ruleId)"]
            if !rule.description.isEmpty { commentParts.append(rule.description) }
            header += "  ; \(commentParts.joined(separator: " "))"

            var lines = [header]
            let maxAccount = rule.postings.map(\.account.count).max() ?? 40
            let accountWidth = max(maxAccount + 4, 40)

            for posting in rule.postings {
                if !posting.amounts.isEmpty {
                    let amountStr = posting.amounts[0].formatted()
                    let padding = String(repeating: " ", count: accountWidth - posting.account.count)
                    lines.append("    \(posting.account)\(padding)\(amountStr)")
                } else {
                    lines.append("    \(posting.account)")
                }
            }

            blocks.append(lines.joined(separator: "\n"))
        }

        return blocks.joined(separator: "\n\n") + "\n"
    }
}

// MARK: - RecurringManager (public API wrapper)

/// Thin wrapper around `RuleFileManager<RecurringRuleFile>` that preserves the
/// original `RecurringManager` call surface used by views and tests.
/// Transaction-generation helpers (`generateOccurrences`, `computePending`,
/// `generateTransactions`) are unique to recurring rules and remain here.
enum RecurringManager {

    static let supportedPeriods = [
        "daily", "weekly", "biweekly", "monthly", "bimonthly", "quarterly", "yearly"
    ]

    // MARK: File path

    static func recurringPath(for journalFile: URL) -> URL {
        RuleFileManager<RecurringRuleFile>.filePath(for: journalFile)
    }

    // MARK: Ensure file exists

    static func ensureRecurringFile(journalFile: URL) throws {
        try RuleFileManager<RecurringRuleFile>.ensureFile(journalFile: journalFile)
    }

    // MARK: Parse / format

    static func parseRules(recurringPath: URL) -> [RecurringRule] {
        RuleFileManager<RecurringRuleFile>.parseRules(at: recurringPath)
    }

    static func formatRules(_ rules: [RecurringRule]) -> String {
        RuleFileManager<RecurringRuleFile>.formatRules(rules)
    }

    // MARK: Write

    static func writeRules(
        _ rules: [RecurringRule],
        recurringPath: URL,
        journalFile: URL,
        validator: any AccountingBackend
    ) async throws {
        try await RuleFileManager<RecurringRuleFile>.writeRules(
            rules, to: recurringPath, journalFile: journalFile, validator: validator
        )
    }

    // MARK: CRUD

    static func addRule(_ rule: RecurringRule, journalFile: URL, validator: any AccountingBackend) async throws {
        try await RuleFileManager<RecurringRuleFile>.addRule(rule, journalFile: journalFile, validator: validator)
    }

    static func updateRule(ruleId: String, newRule: RecurringRule, journalFile: URL, validator: any AccountingBackend) async throws {
        try await RuleFileManager<RecurringRuleFile>.updateRule(key: ruleId, newRule: newRule, journalFile: journalFile, validator: validator)
    }

    static func deleteRule(ruleId: String, journalFile: URL, validator: any AccountingBackend) async throws {
        try await RuleFileManager<RecurringRuleFile>.deleteRule(key: ruleId, journalFile: journalFile, validator: validator)
    }

    // MARK: Transaction Generation

    /// Generate occurrence dates for a rule from start to today.
    static func generateOccurrences(start: Date, period: String, end: Date) -> [Date] {
        var dates: [Date] = []
        let calendar = Calendar.current
        let canonicalDay = calendar.component(.day, from: start)
        var current = start

        while current <= end {
            dates.append(current)

            switch period {
            case "daily":
                current = calendar.date(byAdding: .day, value: 1, to: current)!
            case "weekly":
                current = calendar.date(byAdding: .weekOfYear, value: 1, to: current)!
            case "biweekly":
                current = calendar.date(byAdding: .weekOfYear, value: 2, to: current)!
            case "monthly":
                current = advanceMonth(current, by: 1, canonicalDay: canonicalDay)
            case "bimonthly":
                current = advanceMonth(current, by: 2, canonicalDay: canonicalDay)
            case "quarterly":
                current = advanceMonth(current, by: 3, canonicalDay: canonicalDay)
            case "yearly":
                current = advanceMonth(current, by: 12, canonicalDay: canonicalDay)
            default:
                return dates
            }
        }

        return dates
    }

    private static func advanceMonth(_ date: Date, by months: Int, canonicalDay: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: date)
        components.month! += months
        while components.month! > 12 {
            components.month! -= 12
            components.year! += 1
        }
        let maxDay = calendar.range(of: .day, in: .month, for: calendar.date(from: components)!)!.upperBound - 1
        components.day = min(canonicalDay, maxDay)
        return calendar.date(from: components)!
    }

    /// Compute pending dates for a rule (not yet generated).
    static func computePending(rule: RecurringRule, backend: any AccountingBackend) async -> [Date] {
        guard let startStr = rule.startDate else { return [] }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let start = f.date(from: startStr) else { return [] }

        let calendar = Calendar.current
        let today = Date()
        let lastDayOfMonth = calendar.range(of: .day, in: .month, for: today)!.upperBound - 1
        var end = calendar.date(bySetting: .day, value: lastDayOfMonth, of: today)!

        if let endStr = rule.endDate, let endDate = f.date(from: endStr) {
            end = min(end, endDate)
        }

        let allDates = generateOccurrences(start: start, period: rule.periodExpr, end: end)

        let generated: [Transaction]
        do {
            generated = try await backend.loadTransactions(query: "tag:rule-id=\(rule.ruleId)", reversed: false)
        } catch {
            generated = []
        }
        let generatedDates = Set(generated.map(\.date))

        return allDates.filter { date in
            !generatedDates.contains(f.string(from: date))
        }
    }

    /// Generate and append transactions for pending dates.
    static func generateTransactions(rule: RecurringRule, dates: [Date], backend: any AccountingBackend) async throws {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"

        for date in dates {
            let txn = Transaction(
                index: 0,
                date: f.string(from: date),
                description: rule.description,
                postings: rule.postings,
                status: rule.status,
                code: rule.code,
                comment: "rule-id:\(rule.ruleId)"
            )
            try await backend.appendTransaction(txn)
        }
    }
}
