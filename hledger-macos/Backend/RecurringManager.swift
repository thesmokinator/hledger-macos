/// Recurring transactions file management: read/write periodic rules in recurring.journal.
///
/// Ported from hledger-textual/recurring.py.

import Foundation

enum RecurringManager {
    static let recurringFilename = "recurring.journal"

    static let supportedPeriods = [
        "daily", "weekly", "biweekly", "monthly", "bimonthly", "quarterly", "yearly"
    ]

    // MARK: - File Path

    static func recurringPath(for journalFile: URL) -> URL {
        journalFile.deletingLastPathComponent().appendingPathComponent(recurringFilename)
    }

    // MARK: - Ensure File Exists

    static func ensureRecurringFile(journalFile: URL) throws {
        let recurringFile = recurringPath(for: journalFile)

        if !FileManager.default.fileExists(atPath: recurringFile.path) {
            try "".write(to: recurringFile, atomically: true, encoding: .utf8)
        }

        var journalText = try String(contentsOf: journalFile, encoding: .utf8)
        let hasInclude = journalText.split(separator: "\n").contains { line in
            line.trimmingCharacters(in: .whitespaces).hasPrefix("include \(recurringFilename)")
        }

        if !hasInclude {
            let includeLine = "include \(recurringFilename)\n\n"
            journalText = includeLine + journalText
            try journalText.write(to: journalFile, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Parse Rules

    static func parseRules(recurringPath: URL) -> [RecurringRule] {
        guard FileManager.default.fileExists(atPath: recurringPath.path),
              let content = try? String(contentsOf: recurringPath, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

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
                    // Balancing posting (no amount)
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

    // MARK: - Format Rules

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

    // MARK: - Write Rules

    static func writeRules(_ rules: [RecurringRule], recurringPath: URL, journalFile: URL, validator: any AccountingBackend) async throws {
        let backup = recurringPath.appendingPathExtension("bak")
        if FileManager.default.fileExists(atPath: recurringPath.path) {
            try FileManager.default.copyItem(at: recurringPath, to: backup)
        }

        do {
            let content = formatRules(rules)
            try content.write(to: recurringPath, atomically: true, encoding: .utf8)
            try await validator.validateJournal()
            try? FileManager.default.removeItem(at: backup)
        } catch {
            if FileManager.default.fileExists(atPath: backup.path) {
                try? FileManager.default.removeItem(at: recurringPath)
                try? FileManager.default.moveItem(at: backup, to: recurringPath)
            }
            try? FileManager.default.removeItem(at: backup)
            throw BackendError.journalValidationFailed("Recurring validation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - CRUD

    static func addRule(_ rule: RecurringRule, journalFile: URL, validator: any AccountingBackend) async throws {
        let path = recurringPath(for: journalFile)
        try ensureRecurringFile(journalFile: journalFile)
        var rules = parseRules(recurringPath: path)
        if rules.contains(where: { $0.ruleId == rule.ruleId }) {
            throw BackendError.commandFailed("Recurring rule already exists with id: \(rule.ruleId)")
        }
        rules.append(rule)
        try await writeRules(rules, recurringPath: path, journalFile: journalFile, validator: validator)
    }

    static func updateRule(ruleId: String, newRule: RecurringRule, journalFile: URL, validator: any AccountingBackend) async throws {
        let path = recurringPath(for: journalFile)
        var rules = parseRules(recurringPath: path)
        guard let index = rules.firstIndex(where: { $0.ruleId == ruleId }) else {
            throw BackendError.commandFailed("No recurring rule found with id: \(ruleId)")
        }
        rules[index] = newRule
        try await writeRules(rules, recurringPath: path, journalFile: journalFile, validator: validator)
    }

    static func deleteRule(ruleId: String, journalFile: URL, validator: any AccountingBackend) async throws {
        let path = recurringPath(for: journalFile)
        var rules = parseRules(recurringPath: path)
        let count = rules.count
        rules.removeAll { $0.ruleId == ruleId }
        if rules.count == count {
            throw BackendError.commandFailed("No recurring rule found with id: \(ruleId)")
        }
        try await writeRules(rules, recurringPath: path, journalFile: journalFile, validator: validator)
    }

    // MARK: - Transaction Generation

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

        // Load already-generated transactions tagged with this rule's ID
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
