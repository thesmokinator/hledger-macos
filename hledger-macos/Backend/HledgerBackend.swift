/// hledger CLI backend — communicates with the `hledger` binary via subprocess.
///
/// Ported from hledger-textual/hledger.py.

import Foundation

final class HledgerBackend: AccountingBackend, @unchecked Sendable {
    let binaryPath: String
    let journalFile: URL
    private let runner: SubprocessRunner

    init(binaryPath: String, journalFile: URL) {
        self.binaryPath = binaryPath
        self.journalFile = journalFile
        self.runner = SubprocessRunner(executablePath: binaryPath)
    }

    // MARK: - Helpers

    /// Run hledger with `-f <journalFile>` prepended.
    private func runHledger(_ args: String...) async throws -> String {
        try await runHledger(args)
    }

    private func runHledger(_ args: [String]) async throws -> String {
        var fullArgs = ["-f", journalFile.path]
        fullArgs.append(contentsOf: args)
        return try await runner.run(fullArgs)
    }

    // MARK: - Validation

    func validateJournal() async throws {
        _ = try await runHledger("check")
    }

    // MARK: - Version

    func version() async throws -> String {
        let raw = try await runner.run(["--version"])
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("hledger ") {
            return String(trimmed.dropFirst("hledger ".count)).trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }

    // MARK: - Transactions

    func loadTransactions(query: String?, reversed: Bool) async throws -> [Transaction] {
        var args = ["print", "-O", "json"]
        if let query, !query.isEmpty {
            let expanded = Self.expandSearchQuery(query)
            args.append(contentsOf: expanded.split(separator: " ").map(String.init))
        }

        let output = try await runHledger(args)
        guard let data = output.data(using: .utf8) else {
            throw BackendError.parseError("Invalid UTF-8 output from hledger")
        }

        let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        let transactions = jsonArray.map { Self.parseTransaction($0) }
        return reversed ? transactions.reversed() : transactions
    }

    // MARK: - Accounts

    func loadAccounts() async throws -> [String] {
        let output = try await runHledger("accounts")
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func loadAccountBalances() async throws -> [(String, String)] {
        let output = try await runHledger("balance", "--flat", "--no-total", "-O", "csv")
        return Self.parseCSVAccountBalances(output)
    }

    func loadAccountTreeBalances() async throws -> [AccountNode] {
        let output = try await runHledger("balance", "--tree", "--no-total", "-O", "csv")
        return Self.parseCSVAccountTree(output)
    }

    // MARK: - Descriptions & Commodities

    func loadDescriptions() async throws -> [String] {
        let output = try await runHledger("descriptions")
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func loadCommodities() async throws -> [String] {
        let output = try await runHledger("commodities")
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Stats

    func loadJournalStats() async throws -> JournalStats {
        let output = try await runHledger("stats")

        var txnCount = 0
        var acctCount = 0

        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Txns") || trimmed.hasPrefix("Transactions") {
                if let match = trimmed.firstMatch(of: /:\s*(\d+)/) {
                    txnCount = Int(match.1) ?? 0
                }
            } else if trimmed.hasPrefix("Accounts") {
                if let match = trimmed.firstMatch(of: /:\s*(\d+)/) {
                    acctCount = Int(match.1) ?? 0
                }
            }
        }

        let commodities = try await loadCommodities()
        return JournalStats(
            transactionCount: txnCount,
            accountCount: acctCount,
            commodities: commodities
        )
    }

    // MARK: - Period Summary

    func loadPeriodSummary(period: String?) async throws -> PeriodSummary {
        var periodArgs: [String] = []
        if let period, !period.isEmpty {
            periodArgs = ["-p", period]
        }

        // Income (type:R = revenue accounts)
        var incomeTotal: Decimal = 0
        var commodity = ""
        let incomeOutput = try await runHledger(
            ["balance", "type:R"] + periodArgs + ["--flat", "--no-total", "-O", "csv"]
        )
        for (_, balance) in Self.parseCSVAccountBalances(incomeOutput) {
            let (qty, com) = Self.parseBudgetAmount(balance)
            if commodity.isEmpty && !com.isEmpty { commodity = com }
            incomeTotal += abs(qty)
        }

        // Expenses (type:X = expense accounts)
        var expenseTotal: Decimal = 0
        let expenseOutput = try await runHledger(
            ["balance", "type:X"] + periodArgs + ["--flat", "--no-total", "-O", "csv"]
        )
        for (_, balance) in Self.parseCSVAccountBalances(expenseOutput) {
            let (qty, com) = Self.parseBudgetAmount(balance)
            if commodity.isEmpty && !com.isEmpty { commodity = com }
            expenseTotal += abs(qty)
        }

        // Investments at cost
        var investmentTotal: Decimal = 0
        if let invOutput = try? await runHledger(
            ["balance", "assets:investments", "-B"] + periodArgs + ["--flat", "--no-total", "-O", "csv"]
        ) {
            for (_, balance) in Self.parseCSVAccountBalances(invOutput) {
                let (qty, com) = Self.parseBudgetAmount(balance)
                if commodity.isEmpty && !com.isEmpty { commodity = com }
                investmentTotal += abs(qty)
            }
        }

        return PeriodSummary(
            income: incomeTotal,
            expenses: expenseTotal,
            commodity: commodity,
            investments: investmentTotal
        )
    }

    // MARK: - Breakdowns

    /// Load per-account breakdown for a given account type and period.
    /// Returns (account, amount, commodity) tuples sorted by amount descending.
    func loadAccountBreakdown(typeQuery: String, period: String?) async throws -> [(String, Decimal, String)] {
        var args = ["balance", typeQuery, "--flat", "--no-total", "-O", "csv"]
        if let period, !period.isEmpty {
            args.append(contentsOf: ["-p", period])
        }
        let output = try await runHledger(args)
        var results: [(String, Decimal, String)] = []
        for (account, balance) in Self.parseCSVAccountBalances(output) {
            let (qty, com) = Self.parseBudgetAmount(balance)
            if qty != 0 {
                results.append((account, abs(qty), com))
            }
        }
        return results.sorted { $0.1 > $1.1 }
    }

    /// Load expense breakdown for a period.
    func loadExpenseBreakdown(period: String?) async throws -> [(String, Decimal, String)] {
        try await loadAccountBreakdown(typeQuery: "type:X", period: period)
    }

    /// Load income breakdown for a period.
    func loadIncomeBreakdown(period: String?) async throws -> [(String, Decimal, String)] {
        try await loadAccountBreakdown(typeQuery: "type:R", period: period)
    }

    /// Load liabilities breakdown (all-time, no period filter).
    func loadLiabilitiesBreakdown() async throws -> [(String, Decimal, String)] {
        try await loadAccountBreakdown(typeQuery: "type:L", period: nil)
    }

    // MARK: - Investments

    /// Load investment positions: (account, quantity, commodity) for non-currency holdings.
    func loadInvestmentPositions() async throws -> [(String, Decimal, String)] {
        let output = try await runHledger(
            "balance", "acct:assets:investments", "--flat", "--no-total", "-O", "csv"
        )
        var results: [(String, Decimal, String)] = []
        for (account, balance) in Self.parseCSVAccountBalances(output) {
            let (qty, com) = Self.parseBudgetAmount(balance)
            // Only non-currency commodities (named, length > 1 letter)
            if !com.isEmpty && com.count > 1 && com.first?.isLetter == true && qty != 0 {
                results.append((account, qty, com))
            }
        }
        return results
    }

    /// Load investment book values (purchase cost) per account.
    func loadInvestmentCost() async throws -> [String: (Decimal, String)] {
        let output = try await runHledger(
            "balance", "acct:assets:investments", "--flat", "--no-total", "--cost", "-O", "csv"
        )
        var results: [String: (Decimal, String)] = [:]
        for (account, balance) in Self.parseCSVAccountBalances(output) {
            let (qty, com) = Self.parseBudgetAmount(balance)
            results[account] = (qty, com)
        }
        return results
    }

    /// Load investment market values using a prices file for -V valuation.
    func loadInvestmentMarketValues(pricesFile: URL) async throws -> [String: (Decimal, String)] {
        let output = try await runHledger([
            "balance", "acct:assets:investments", "--flat", "--no-total", "-V",
            "-O", "csv", "-f", pricesFile.path
        ])
        var results: [String: (Decimal, String)] = [:]
        for (account, balance) in Self.parseCSVAccountBalances(output) {
            let (qty, com) = Self.parseBudgetAmount(balance)
            results[account] = (qty, com)
        }
        return results
    }

    // MARK: - Reports

    func loadReport(
        type: ReportType,
        periodBegin: String?,
        periodEnd: String?,
        commodity: String?
    ) async throws -> ReportData {
        var args = [type.rawValue, "-M", "-O", "csv", "--no-elide"]
        if let begin = periodBegin, !begin.isEmpty {
            args.append(contentsOf: ["-b", begin])
        }
        if let end = periodEnd, !end.isEmpty {
            args.append(contentsOf: ["-e", end])
        }
        if let commodity, !commodity.isEmpty {
            args.append(contentsOf: ["-X", commodity])
        }

        let output = try await runHledger(args)
        return Self.parseCSVReport(output, title: type.displayName)
    }

    // MARK: - Budget

    func loadBudgetReport(period: String) async throws -> [BudgetRow] {
        let output = try await runHledger(
            "balance", "--budget", "-p", period, "-O", "csv", "--no-total", "Expenses"
        )
        return Self.parseCSVBudgetReport(output)
    }

    // MARK: - Write Operations

    func appendTransaction(_ transaction: Transaction) async throws {
        try await JournalWriter.append(
            transaction: transaction,
            mainJournal: journalFile,
            validator: self
        )
    }

    func replaceTransaction(_ original: Transaction, with new: Transaction) async throws {
        try await JournalWriter.replace(
            original: original,
            with: new,
            mainJournal: journalFile,
            validator: self
        )
    }

    func deleteTransaction(_ transaction: Transaction) async throws {
        try await JournalWriter.delete(
            transaction: transaction,
            mainJournal: journalFile,
            validator: self
        )
    }
}

// MARK: - JSON Parsing

extension HledgerBackend {
    /// Parse a transaction from hledger `print -O json` output.
    static func parseTransaction(_ data: [String: Any]) -> Transaction {
        let postings = (data["tpostings"] as? [[String: Any]] ?? []).map { parsePosting($0) }
        let statusStr = data["tstatus"] as? String ?? "Unmarked"
        let status = TransactionStatus(rawValue: statusStr) ?? .unmarked

        var sourcePosStart: SourcePosition?
        var sourcePosEnd: SourcePosition?
        if let sp = data["tsourcepos"] as? [[String: Any]], sp.count == 2 {
            sourcePosStart = parseSourcePosition(sp[0])
            sourcePosEnd = parseSourcePosition(sp[1])
        }

        let rawTags = data["ttags"] as? [[Any]] ?? []
        let tags = rawTags.compactMap { pair -> String? in
            guard let name = pair.first as? String else { return nil }
            let value = pair.count > 1 ? (pair[1] as? String ?? "") : ""
            return value.isEmpty ? name : "\(name):\(value)"
        }

        return Transaction(
            index: data["tindex"] as? Int ?? 0,
            date: data["tdate"] as? String ?? "",
            description: data["tdescription"] as? String ?? "",
            postings: postings,
            status: status,
            code: data["tcode"] as? String ?? "",
            comment: (data["tcomment"] as? String ?? "").trimmingCharacters(in: .whitespaces),
            date2: data["tdate2"] as? String,
            sourcePosStart: sourcePosStart,
            sourcePosEnd: sourcePosEnd,
            tags: tags
        )
    }

    static func parsePosting(_ data: [String: Any]) -> Posting {
        let amounts = (data["pamount"] as? [[String: Any]] ?? []).map { parseAmount($0) }
        let statusStr = data["pstatus"] as? String ?? "Unmarked"
        let status = TransactionStatus(rawValue: statusStr) ?? .unmarked

        return Posting(
            account: data["paccount"] as? String ?? "",
            amounts: amounts,
            comment: (data["pcomment"] as? String ?? "").trimmingCharacters(in: .whitespaces),
            status: status
        )
    }

    static func parseAmount(_ data: [String: Any]) -> Amount {
        let qtyData = data["aquantity"] as? [String: Any] ?? [:]
        let mantissa = qtyData["decimalMantissa"] as? Int ?? 0
        let places = qtyData["decimalPlaces"] as? Int ?? 0
        let quantity = Decimal(mantissa) / pow(10, places)

        let styleData = data["astyle"] as? [String: Any] ?? [:]
        let sideStr = styleData["ascommodityside"] as? String ?? "L"
        let side = CommoditySide(rawValue: sideStr) ?? .left

        var separator: String?
        var sizes: [Int] = []
        if let digitGroups = styleData["asdigitgroups"] as? [Any], digitGroups.count == 2 {
            separator = digitGroups[0] as? String
            sizes = digitGroups[1] as? [Int] ?? []
        }

        let style = AmountStyle(
            commoditySide: side,
            commoditySpaced: styleData["ascommodityspaced"] as? Bool ?? false,
            decimalMark: styleData["asdecimalmark"] as? String ?? ".",
            digitGroupSeparator: separator,
            digitGroupSizes: sizes,
            precision: styleData["asprecision"] as? Int ?? 2
        )

        // Parse cost annotation (@/@@)
        var cost: CostAmount?
        if let acost = data["acost"] as? [String: Any],
           let contents = acost["contents"] as? [String: Any] {
            let tag = acost["tag"] as? String ?? ""
            var costAmount = parseAmount(contents)
            if tag == "UnitCost" {
                costAmount = Amount(
                    commodity: costAmount.commodity,
                    quantity: abs(costAmount.quantity * quantity),
                    style: costAmount.style
                )
            } else {
                costAmount = Amount(
                    commodity: costAmount.commodity,
                    quantity: abs(costAmount.quantity),
                    style: costAmount.style
                )
            }
            cost = CostAmount(
                commodity: costAmount.commodity,
                quantity: costAmount.quantity,
                style: costAmount.style
            )
        }

        return Amount(
            commodity: data["acommodity"] as? String ?? "",
            quantity: quantity,
            style: style,
            cost: cost
        )
    }

    static func parseSourcePosition(_ data: [String: Any]) -> SourcePosition {
        SourcePosition(
            sourceName: data["sourceName"] as? String ?? "",
            sourceLine: data["sourceLine"] as? Int ?? 0,
            sourceColumn: data["sourceColumn"] as? Int ?? 0
        )
    }
}

// MARK: - CSV Parsing

extension HledgerBackend {
    /// Parse CSV output from `hledger balance --flat -O csv`.
    static func parseCSVAccountBalances(_ csv: String) -> [(String, String)] {
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count > 1 else { return [] }

        var results: [(String, String)] = []
        for line in lines.dropFirst() {
            let fields = parseCSVLine(line)
            if fields.count >= 2, !fields[0].isEmpty, !fields[1].isEmpty {
                results.append((fields[0], fields[1]))
            }
        }
        return results
    }

    /// Parse CSV output from `hledger balance --tree -O csv` into a tree.
    /// Parse CSV tree output into AccountNode hierarchy.
    ///
    /// Builds the tree bottom-up to work correctly with value types:
    /// collects flat nodes first, then assembles parents from their children in reverse.
    static func parseCSVAccountTree(_ csv: String) -> [AccountNode] {
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count > 1 else { return [] }

        struct FlatNode {
            let name: String
            let balance: String
            let depth: Int
        }

        var flatNodes: [FlatNode] = []
        for line in lines.dropFirst() {
            let fields = parseCSVLine(line)
            guard fields.count >= 2, !fields[0].isEmpty else { continue }
            let rawName = fields[0]
            let balance = fields[1]
            let stripped = rawName.drop(while: { $0 == " " || $0 == "\u{00A0}" })
            let indent = rawName.count - stripped.count
            let depth = indent / 2
            flatNodes.append(FlatNode(name: String(stripped), balance: balance, depth: depth))
        }

        guard !flatNodes.isEmpty else { return [] }

        // Resolve full paths
        var fullPaths: [String] = []
        var pathStack: [String] = []
        for node in flatNodes {
            while pathStack.count > node.depth { pathStack.removeLast() }
            if pathStack.isEmpty {
                pathStack.append(node.name)
            } else {
                pathStack.append(node.name)
            }
            fullPaths.append(pathStack.joined(separator: ":"))
        }

        // Build tree bottom-up: process nodes in reverse so children are complete before parents
        var builtNodes: [AccountNode?] = Array(repeating: nil, count: flatNodes.count)

        for i in stride(from: flatNodes.count - 1, through: 0, by: -1) {
            let flat = flatNodes[i]
            // Collect children: next nodes with depth == flat.depth + 1 (until we hit same or lower depth)
            var children: [AccountNode] = []
            var j = i + 1
            while j < flatNodes.count && flatNodes[j].depth > flat.depth {
                if flatNodes[j].depth == flat.depth + 1, let built = builtNodes[j] {
                    children.append(built)
                }
                j += 1
            }

            builtNodes[i] = AccountNode(
                name: flat.name,
                fullPath: fullPaths[i],
                balance: flat.balance,
                depth: flat.depth,
                children: children
            )
        }

        // Roots are depth-0 nodes
        return builtNodes.enumerated().compactMap { index, node in
            flatNodes[index].depth == 0 ? node : nil
        }
    }

    /// Parse CSV report output (IS, BS, CF).
    /// hledger CSV reports have two header rows:
    ///   Row 1: title row (e.g. "Monthly Income Statement 2025-10-01..2026-03-31")
    ///   Row 2: column headers ("Account","2025-10","2025-11",...)
    static func parseCSVReport(_ csv: String, title: String) -> ReportData {
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count >= 2 else {
            return ReportData(title: title)
        }

        // Skip title row (line 0), use line 1 as column headers
        let headers = parseCSVLine(lines[1])
        let periodHeaders = Array(headers.dropFirst())

        var rows: [ReportRow] = []
        for line in lines.dropFirst(2) {
            let fields = parseCSVLine(line)
            guard !fields.isEmpty else { continue }
            let account = fields[0].trimmingCharacters(in: .whitespaces)
            guard !account.isEmpty else { continue }
            let amounts = Array(fields.dropFirst())

            let lc = account.lowercased()
            let isTotal = lc.contains("total") || lc.contains("net:")
            let allEmpty = amounts.allSatisfy {
                let t = $0.trimmingCharacters(in: .whitespaces)
                return t.isEmpty || t == "0"
            }
            let isSectionHeader = !isTotal && allEmpty && !account.contains(":")

            rows.append(ReportRow(
                account: account,
                amounts: amounts,
                isSectionHeader: isSectionHeader,
                isTotal: isTotal
            ))
        }

        return ReportData(title: title, periodHeaders: periodHeaders, rows: rows)
    }

    /// Parse CSV budget report.
    static func parseCSVBudgetReport(_ csv: String) -> [BudgetRow] {
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count > 1 else { return [] }

        var results: [BudgetRow] = []
        for line in lines.dropFirst() {
            let fields = parseCSVLine(line)
            guard !fields.isEmpty, !fields[0].isEmpty else { continue }
            let account = fields[0].trimmingCharacters(in: CharacterSet(charactersIn: "\""))

            var actual: Decimal = 0
            var budget: Decimal = 0
            var commodity = ""

            if fields.count >= 2 {
                let cell = fields[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                if cell.contains("=") {
                    let parts = cell.split(separator: "=", maxSplits: 1).map(String.init)
                    let actualStr = parts[0].trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: "[", with: "")
                    let budgetStr = parts.count > 1
                        ? parts[1].trimmingCharacters(in: .whitespaces)
                            .replacingOccurrences(of: "]", with: "")
                        : ""
                    (actual, commodity) = Self.parseBudgetAmount(actualStr)
                    (budget, _) = Self.parseBudgetAmount(budgetStr)
                } else {
                    (actual, commodity) = Self.parseBudgetAmount(cell)
                }
            }

            if fields.count >= 3 && budget == 0 {
                let budgetCell = fields[2].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                let (b, bcom) = Self.parseBudgetAmount(budgetCell)
                budget = b
                if commodity.isEmpty { commodity = bcom }
            }

            if !account.isEmpty && (actual != 0 || budget != 0) {
                results.append(BudgetRow(account: account, actual: actual, budget: budget, commodity: commodity))
            }
        }

        return results
    }

    /// Parse a budget amount string. Delegates to shared AmountParser.
    static func parseBudgetAmount(_ s: String) -> (Decimal, String) {
        AmountParser.parse(s)
    }

    /// Simple CSV line parser handling quoted fields.
    static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }
}

// MARK: - Search Query Expansion

extension HledgerBackend {
    /// Short aliases for hledger query prefixes.
    private static let queryAliases: [(alias: String, full: String)] = [
        ("d:", "desc:"),
        ("ac:", "acct:"),
        ("am:", "amt:"),
        ("t:", "tag:"),
        ("st:", "status:"),
    ]

    /// Expand short search aliases to full hledger query prefixes.
    static func expandSearchQuery(_ query: String) -> String {
        guard !query.isEmpty else { return query }
        var result = query
        for (alias, full) in queryAliases {
            result = result.replacingOccurrences(of: alias, with: full)
        }
        return result
    }
}
