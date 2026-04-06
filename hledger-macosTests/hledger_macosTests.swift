import Testing
import Foundation
@testable import hledger_for_Mac

// MARK: - AmountParser Tests

@Suite("AmountParser")
struct AmountParserTests {
    @Test func leftSideCurrency() {
        let (qty, com) = AmountParser.parse("€500.00")
        #expect(qty == Decimal(string: "500.00"))
        #expect(com == "€")
    }

    @Test func rightSideCommodity() {
        let (qty, com) = AmountParser.parse("500.00 EUR")
        #expect(qty == Decimal(string: "500.00"))
        #expect(com == "EUR")
    }

    @Test func negativeAmount() {
        let (qty, com) = AmountParser.parse("-123.45")
        #expect(qty == Decimal(string: "-123.45"))
        #expect(com == "")
    }

    @Test func zeroString() {
        let (qty, com) = AmountParser.parse("0")
        #expect(qty == 0)
        #expect(com == "")
    }

    @Test func emptyString() {
        let (qty, com) = AmountParser.parse("")
        #expect(qty == 0)
        #expect(com == "")
    }

    @Test func europeanFormat() {
        let (qty, com) = AmountParser.parse("€ 1.000,50")
        #expect(qty == Decimal(string: "1000.5"))
        #expect(com == "€")
    }

    @Test func europeanFormatNoThousands() {
        let (qty, com) = AmountParser.parse("€ 50,00")
        #expect(qty == Decimal(string: "50"))
        #expect(com == "€")
    }

    @Test func usFormat() {
        let (qty, com) = AmountParser.parse("$1,000.50")
        #expect(qty == Decimal(string: "1000.5"))
        #expect(com == "$")
    }

    @Test func parseNumberEuropean() {
        #expect(AmountParser.parseNumber("1.000,00") == 1000)
        #expect(AmountParser.parseNumber("50,00") == 50)
        #expect(AmountParser.parseNumber("1.234.567,89") == Decimal(string: "1234567.89"))
    }

    @Test func parseNumberUS() {
        #expect(AmountParser.parseNumber("1,000.00") == 1000)
        #expect(AmountParser.parseNumber("50.00") == 50)
    }

    @Test func parseNumberPlain() {
        #expect(AmountParser.parseNumber("1000") == 1000)
        #expect(AmountParser.parseNumber("-500") == -500)
    }

    @Test func commodityWithQuantity() {
        let (qty, com) = AmountParser.parse("29 XDWD")
        #expect(qty == 29)
        #expect(com == "XDWD")
    }

    @Test func negativeWithCurrency() {
        let (qty, com) = AmountParser.parse("€-174420.00")
        #expect(qty == Decimal(string: "-174420.00"))
        #expect(com == "€")
    }

    // Roundtrip: Amount.formatted() -> AmountParser.parse()
    // These test the exact strings that Amount.formatted() produces
    // for negative amounts, which must survive re-parsing.

    @Test func negativeSignBeforeCurrency() {
        // Amount.formatted() produces "-€50.00" for negative left-side commodity
        let (qty, com) = AmountParser.parse("-€50.00")
        #expect(qty == Decimal(string: "-50.00"))
        #expect(com == "€")
    }

    @Test func negativeSignBeforeDollar() {
        let (qty, com) = AmountParser.parse("-$1000.00")
        #expect(qty == Decimal(string: "-1000.00"))
        #expect(com == "$")
    }

    @Test func negativeSignBeforePound() {
        let (qty, com) = AmountParser.parse("-£25.50")
        #expect(qty == Decimal(string: "-25.50"))
        #expect(com == "£")
    }

    @Test func negativeRightSideCommodity() {
        // Amount.formatted() produces "-50.00 EUR" for negative right-side commodity
        let (qty, com) = AmountParser.parse("-50.00 EUR")
        #expect(qty == Decimal(string: "-50.00"))
        #expect(com == "EUR")
    }

    @Test func roundtripPositiveLeftSide() {
        let amount = Amount(commodity: "€", quantity: Decimal(string: "50.00")!, style: AmountStyle(commoditySide: .left, precision: 2))
        let formatted = amount.formatted()
        let (qty, com) = AmountParser.parse(formatted)
        #expect(qty == Decimal(string: "50.00"))
        #expect(com == "€")
    }

    @Test func roundtripNegativeLeftSide() {
        let amount = Amount(commodity: "€", quantity: Decimal(string: "-50.00")!, style: AmountStyle(commoditySide: .left, precision: 2))
        let formatted = amount.formatted()
        let (qty, com) = AmountParser.parse(formatted)
        #expect(qty == Decimal(string: "-50.00"))
        #expect(com == "€")
    }

    @Test func roundtripPositiveRightSide() {
        let amount = Amount(commodity: "EUR", quantity: Decimal(string: "1234.56")!, style: AmountStyle(commoditySide: .right, precision: 2))
        let formatted = amount.formatted()
        let (qty, com) = AmountParser.parse(formatted)
        #expect(qty == Decimal(string: "1234.56"))
        #expect(com == "EUR")
    }

    @Test func roundtripNegativeRightSide() {
        let amount = Amount(commodity: "EUR", quantity: Decimal(string: "-1234.56")!, style: AmountStyle(commoditySide: .right, precision: 2))
        let formatted = amount.formatted()
        let (qty, com) = AmountParser.parse(formatted)
        #expect(qty == Decimal(string: "-1234.56"))
        #expect(com == "EUR")
    }
}

// MARK: - AmountFormatter Tests

@Suite("AmountFormatter")
struct AmountFormatterTests {
    @Test func currencySymbolLeft() {
        let result = AmountFormatter.format(1234.56, commodity: "€")
        #expect(result.hasPrefix("€"))
    }

    @Test func namedCommodityRight() {
        let result = AmountFormatter.format(500, commodity: "EUR")
        #expect(result.hasSuffix("EUR"))
    }

    @Test func quantityNoTrailingZeros() {
        let result = AmountFormatter.formatQuantity(29)
        #expect(result == "29")
    }
}

// MARK: - TransactionFormatter Tests

@Suite("TransactionFormatter")
struct TransactionFormatterTests {
    @Test func basicTransaction() {
        let txn = Transaction(
            index: 0, date: "2026-03-15", description: "Test purchase",
            postings: [
                Posting(account: "expenses:food", amounts: [
                    Amount(commodity: "€", quantity: Decimal(string: "50.00")!)
                ]),
                Posting(account: "assets:bank")
            ],
            status: .cleared
        )
        let result = TransactionFormatter.format(txn)
        #expect(result.contains("2026-03-15"))
        #expect(result.contains("*"))
        #expect(result.contains("Test purchase"))
        #expect(result.contains("expenses:food"))
        #expect(result.contains("assets:bank"))
    }

    @Test func pendingStatus() {
        let txn = Transaction(index: 0, date: "2026-01-01", description: "Test", status: .pending)
        let result = TransactionFormatter.format(txn)
        #expect(result.contains("!"))
    }

    @Test func withCode() {
        let txn = Transaction(index: 0, date: "2026-01-01", description: "Test", code: "INV-001")
        let result = TransactionFormatter.format(txn)
        #expect(result.contains("(INV-001)"))
    }

    @Test func withComment() {
        let txn = Transaction(index: 0, date: "2026-01-01", description: "Test", comment: "my note")
        let result = TransactionFormatter.format(txn)
        #expect(result.contains("; my note"))
    }
}

// MARK: - JournalFileResolver Tests

@Suite("JournalFileResolver")
struct JournalFileResolverTests {
    @Test func nonexistentPathReturnsNil() {
        let result = JournalFileResolver.resolve(configuredPath: "/nonexistent/path/file.journal")
        #expect(result == nil)
    }

    @Test func defaultPathReturnsString() {
        let path = JournalFileResolver.defaultPath()
        #expect(!path.isEmpty)
    }

    @Test func shellDetectedPathUsedWhenNoConfig() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).journal")
        try "".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let result = JournalFileResolver.resolve(configuredPath: "", shellDetectedPath: tmp.path)
        #expect(result == tmp)
    }

    @Test func configuredPathTakesPriorityOverShellDetected() throws {
        let configured = FileManager.default.temporaryDirectory
            .appendingPathComponent("configured-\(UUID().uuidString).journal")
        let detected = FileManager.default.temporaryDirectory
            .appendingPathComponent("detected-\(UUID().uuidString).journal")
        try "".write(to: configured, atomically: true, encoding: .utf8)
        try "".write(to: detected, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: configured)
            try? FileManager.default.removeItem(at: detected)
        }

        let result = JournalFileResolver.resolve(configuredPath: configured.path, shellDetectedPath: detected.path)
        #expect(result == configured)
    }

    @Test func shellDetectedPathSkippedIfNonexistent() {
        let result = JournalFileResolver.resolve(
            configuredPath: "",
            shellDetectedPath: "/nonexistent/shell-detected.journal"
        )
        // Should not crash and should not return the nonexistent path
        #expect(result?.path != "/nonexistent/shell-detected.journal")
    }
}

// MARK: - BinaryDetector Shell Detection Tests

@Suite("BinaryDetector.journalPathFromHledger")
struct BinaryDetectorJournalTests {
    @Test func invalidHledgerPathReturnsNil() {
        let result = BinaryDetector.journalPathFromHledger("/nonexistent/bin/hledger")
        #expect(result == nil)
    }

    @Test func realHledgerReturnsPath() {
        guard let hledgerPath = BinaryDetector.findHledger() else { return }
        // journalPathFromHledger may return nil if no journal is configured — that's fine.
        // What we verify is that it doesn't crash and returns a valid absolute path if non-nil.
        let result = BinaryDetector.journalPathFromHledger(hledgerPath)
        if let path = result {
            #expect(!path.isEmpty)
            #expect(path.hasPrefix("/"))
        }
    }
}

// MARK: - BinaryDetector Tests

@Suite("BinaryDetector")
struct BinaryDetectorTests {
    @Test func invalidCustomPathNotUsed() {
        // Even with an invalid custom path, detect may still find hledger in known paths
        let result = BinaryDetector.detect(customHledgerPath: "/nonexistent/bin/hledger")
        // The invalid custom path should NOT be returned
        #expect(result.hledgerPath != "/nonexistent/bin/hledger")
    }

    @Test func findHledgerWithInvalidCustom() {
        let path = BinaryDetector.findHledger(customPath: "/nonexistent/bin/hledger")
        // Should not return the invalid path
        if let path { #expect(path != "/nonexistent/bin/hledger") }
    }
}

// MARK: - JournalWriter Routing Tests

@Suite("JournalWriter.RoutingStrategy")
struct JournalWriterRoutingTests {
    @Test func detectsFallback() {
        let content = "; just a comment\n2026-01-01 Test\n    expenses:food  €50\n    assets:bank\n"
        let strategy = JournalWriter.detectRoutingStrategy(content)
        if case .fallback = strategy {} else {
            Issue.record("Expected fallback strategy")
        }
    }

    @Test func detectsFlat() {
        let content = "include 2026-01.journal\ninclude 2026-02.journal\n"
        let strategy = JournalWriter.detectRoutingStrategy(content)
        if case .flat(let files) = strategy {
            #expect(files.contains("2026-01.journal"))
            #expect(files.contains("2026-02.journal"))
        } else {
            Issue.record("Expected flat strategy")
        }
    }

    @Test func detectsGlob() {
        let content = "include 2025/*.journal\ninclude 2026/*.journal\n"
        let strategy = JournalWriter.detectRoutingStrategy(content)
        if case .glob(let years) = strategy {
            #expect(years.contains("2025"))
            #expect(years.contains("2026"))
        } else {
            Issue.record("Expected glob strategy")
        }
    }

    @Test func insertIncludeSorted() {
        let content = "include 2026-01.journal\ninclude 2026-03.journal\n"
        let result = JournalWriter.insertIncludeSorted(content, newInclude: "2026-02.journal")
        let includes = result.components(separatedBy: "\n").filter { $0.hasPrefix("include") }
        #expect(includes.count == 3)
        #expect(includes[1].contains("2026-02"))
    }
}

// MARK: - CSV Parsing Tests

@Suite("HledgerBackend.CSVParsing")
struct CSVParsingTests {
    @Test func parseCSVLine() {
        let fields = HledgerBackend.parseCSVLine("\"account\",\"balance\"")
        #expect(fields == ["account", "balance"])
    }

    @Test func parseCSVLineWithCommaInQuotes() {
        let fields = HledgerBackend.parseCSVLine("\"expenses:food,drink\",\"€50.00\"")
        #expect(fields.count == 2)
        #expect(fields[0] == "expenses:food,drink")
    }

    @Test func parseAccountBalances() {
        let csv = "\"account\",\"balance\"\n\"assets:bank\",\"€5000.00\"\n\"expenses:food\",\"€200.00\"\n"
        let result = HledgerBackend.parseCSVAccountBalances(csv)
        #expect(result.count == 2)
        #expect(result[0].0 == "assets:bank")
    }

    @Test func parseBudgetAmount() {
        let (qty, com) = HledgerBackend.parseBudgetAmount("€1234.56")
        #expect(qty == Decimal(string: "1234.56"))
        #expect(com == "€")
    }
}

// MARK: - Transaction Model Tests

@Suite("Transaction")
struct TransactionModelTests {
    @Test func typeIndicatorExpense() {
        let txn = Transaction(
            index: 0, date: "2026-01-01", description: "Test",
            postings: [Posting(account: "expenses:food"), Posting(account: "assets:bank")]
        )
        #expect(txn.typeIndicator == "E")
    }

    @Test func typeIndicatorIncome() {
        let txn = Transaction(
            index: 0, date: "2026-01-01", description: "Test",
            postings: [Posting(account: "income:salary"), Posting(account: "assets:bank")]
        )
        #expect(txn.typeIndicator == "I")
    }

    @Test func typeIndicatorTransfer() {
        let txn = Transaction(
            index: 0, date: "2026-01-01", description: "Test",
            postings: [Posting(account: "assets:bank"), Posting(account: "assets:savings")]
        )
        #expect(txn.typeIndicator == "-")
    }

    @Test func statusSymbols() {
        #expect(TransactionStatus.cleared.symbol == "*")
        #expect(TransactionStatus.pending.symbol == "!")
        #expect(TransactionStatus.unmarked.symbol == "")
    }
}

// MARK: - UpdateChecker Version Comparison Tests

@Suite("UpdateChecker")
struct UpdateCheckerTests {
    // Base version comparisons
    @Test func sameVersion() {
        #expect(UpdateChecker.compareVersions("1.0.0", "1.0.0") == .orderedSame)
    }

    @Test func newerMajor() {
        #expect(UpdateChecker.compareVersions("1.0.0", "2.0.0") == .orderedAscending)
    }

    @Test func newerMinor() {
        #expect(UpdateChecker.compareVersions("0.1.0", "0.2.0") == .orderedAscending)
    }

    @Test func newerPatch() {
        #expect(UpdateChecker.compareVersions("0.1.0", "0.1.1") == .orderedAscending)
    }

    @Test func olderVersion() {
        #expect(UpdateChecker.compareVersions("1.2.0", "1.1.0") == .orderedDescending)
    }

    // Pre-release comparisons
    @Test func stableNewerThanRC() {
        #expect(UpdateChecker.compareVersions("1.0.0", "1.0.0-rc1") == .orderedDescending)
    }

    @Test func rcOlderThanStable() {
        #expect(UpdateChecker.compareVersions("1.0.0-rc1", "1.0.0") == .orderedAscending)
    }

    @Test func rc1OlderThanRC2() {
        #expect(UpdateChecker.compareVersions("0.1.0-rc1", "0.1.0-rc2") == .orderedAscending)
    }

    @Test func rc3NewerThanRC2() {
        #expect(UpdateChecker.compareVersions("0.1.0-rc3", "0.1.0-rc2") == .orderedDescending)
    }

    @Test func sameRC() {
        #expect(UpdateChecker.compareVersions("0.1.0-rc1", "0.1.0-rc1") == .orderedSame)
    }

    @Test func rcOlderThanNextMinor() {
        #expect(UpdateChecker.compareVersions("0.1.0-rc5", "0.2.0") == .orderedAscending)
    }

    @Test func differentBaseWithRC() {
        #expect(UpdateChecker.compareVersions("0.1.0-rc1", "0.1.1") == .orderedAscending)
    }

    // Split version
    @Test func splitStable() {
        let (base, pre) = UpdateChecker.splitVersion("1.0.0")
        #expect(base == "1.0.0")
        #expect(pre == nil)
    }

    @Test func splitRC() {
        let (base, pre) = UpdateChecker.splitVersion("0.1.0-rc2")
        #expect(base == "0.1.0")
        #expect(pre == "rc2")
    }

    @Test func splitBeta() {
        let (base, pre) = UpdateChecker.splitVersion("1.0.0-beta3")
        #expect(base == "1.0.0")
        #expect(pre == "beta3")
    }
}

// MARK: - TransactionSearchTool Query Formatting Tests

@Suite("TransactionSearchTool.formatQuery")
struct TransactionSearchQueryTests {
    @Test func plainTextBecomesDescQuery() {
        #expect(TransactionSearchTool.formatQuery("Lidl") == "desc:Lidl")
    }

    @Test func plainTextWithSpaces() {
        #expect(TransactionSearchTool.formatQuery("Grenke Italia") == "desc:Grenke Italia")
    }

    @Test func greaterThanBecomesAmtQuery() {
        #expect(TransactionSearchTool.formatQuery(">500") == "amt:>500")
    }

    @Test func lessThanBecomesAmtQuery() {
        #expect(TransactionSearchTool.formatQuery("<100") == "amt:<100")
    }

    @Test func numberBecomesAmtQuery() {
        #expect(TransactionSearchTool.formatQuery("500") == "amt:500")
    }

    @Test func existingPrefixPassedThrough() {
        #expect(TransactionSearchTool.formatQuery("desc:restaurant") == "desc:restaurant")
    }

    @Test func acctPrefixPassedThrough() {
        #expect(TransactionSearchTool.formatQuery("acct:expenses:food") == "acct:expenses:food")
    }

    @Test func datePrefixPassedThrough() {
        #expect(TransactionSearchTool.formatQuery("date:2026-03") == "date:2026-03")
    }

    @Test func amtPrefixPassedThrough() {
        #expect(TransactionSearchTool.formatQuery("amt:>500") == "amt:>500")
    }

    @Test func trimming() {
        #expect(TransactionSearchTool.formatQuery("  Lidl  ") == "desc:Lidl")
    }
}

// MARK: - AI Tool Tests with Mock Backend

/// Minimal mock backend for testing tool output formatting.
struct MockBackend: AccountingBackend {
    var binaryPath: String { "/usr/bin/hledger" }
    var journalFile: URL { URL(fileURLWithPath: "/tmp/test.journal") }

    func validateJournal() async throws {}
    func version() async throws -> String { "1.40" }

    func loadTransactions(query: String?, reversed: Bool) async throws -> [Transaction] {
        if query?.contains("desc:Lidl") == true {
            return [
                Transaction(index: 0, date: "2026-04-01", description: "Lidl",
                            postings: [Posting(account: "Expenses:Groceries",
                                               amounts: [Amount(commodity: "€", quantity: 45.20)])])
            ]
        }
        return []
    }

    func loadDescriptions() async throws -> [String] { ["Lidl", "Amazon"] }
    func loadAccounts() async throws -> [String] { ["Assets:Bank", "Expenses:Groceries"] }
    func loadAccountBalances() async throws -> [(String, String)] {
        [("Assets:Bank", "€8198.21"), ("Assets:Cash", "€153.40")]
    }
    func loadAccountTreeBalances() async throws -> [AccountNode] { [] }
    func loadCommodities() async throws -> [String] { ["€"] }
    func loadJournalStats() async throws -> JournalStats {
        JournalStats(transactionCount: 100, accountCount: 20, commodities: ["€"])
    }
    func loadPeriodSummary(period: String?) async throws -> PeriodSummary {
        PeriodSummary(income: 7341.75, expenses: 1747.95, commodity: "€")
    }
    func loadExpenseBreakdown(period: String?, preferredCommodity: String) async throws -> [(String, Decimal, String)] {
        [("Expenses:School", 407, "€"), ("Expenses:Groceries", 319.17, "€")]
    }
    func loadIncomeBreakdown(period: String?, preferredCommodity: String) async throws -> [(String, Decimal, String)] {
        [("Income:Salary", 7302, "€"), ("Income:Other", 39.75, "€")]
    }
    func loadLiabilitiesBreakdown(preferredCommodity: String) async throws -> [(String, Decimal, String)] {
        [("Liabilities:Mortgage", -150000, "€")]
    }
    func loadAssetsBreakdown(preferredCommodity: String) async throws -> [(String, Decimal, String)] {
        [("Assets:Bank", Decimal(string: "8198.21")!, "€"), ("Assets:Cash", Decimal(string: "153.40")!, "€")]
    }
    func loadMultiCurrencyAccounts() async throws -> Set<String> { [] }
    func loadInvestmentPositions() async throws -> [(String, Decimal, String)] { [] }
    func loadInvestmentCost() async throws -> [String: (Decimal, String)] { [:] }
    func loadInvestmentMarketValues(pricesFile: URL) async throws -> [String: (Decimal, String)] { [:] }
    func loadReport(type: ReportType, periodBegin: String?, periodEnd: String?, commodity: String?) async throws -> ReportData {
        ReportData(title: "Test")
    }
    func loadBudgetReport(period: String) async throws -> [BudgetRow] { [] }
    func appendTransaction(_ transaction: Transaction) async throws {}
    func updateTransactionStatus(_ transaction: Transaction, to newStatus: TransactionStatus) async throws {}
    func replaceTransaction(_ original: Transaction, with new: Transaction) async throws {}
    func deleteTransaction(_ transaction: Transaction) async throws {}
}

@Suite("HledgerTools")
struct HledgerToolTests {
    let backend = MockBackend()

    @Test func expenseBreakdownReturnsData() async throws {
        let tool = ExpenseBreakdownTool(backend: backend)
        let result = try await tool.call(arguments: PeriodQuery(period: "2026-04"))
        #expect(result.contains("Expenses:School"))
        #expect(result.contains("407"))
        #expect(result.contains("Expenses:Groceries"))
        #expect(result.contains("319.17"))
        #expect(result.contains("Total expenses"))
    }

    @Test func incomeBreakdownReturnsData() async throws {
        let tool = IncomeBreakdownTool(backend: backend)
        let result = try await tool.call(arguments: PeriodQuery(period: "2026-04"))
        #expect(result.contains("Income:Salary"))
        #expect(result.contains("7302"))
        #expect(result.contains("Total income"))
    }

    @Test func periodSummaryReturnsData() async throws {
        let tool = PeriodSummaryTool(backend: backend)
        let result = try await tool.call(arguments: PeriodQuery(period: "2026-04"))
        #expect(result.contains("7341.75"))
        #expect(result.contains("1747.95"))
        #expect(result.contains("Net"))
    }

    @Test func accountBalancesReturnsAll() async throws {
        let tool = AccountBalancesTool(backend: backend)
        let result = try await tool.call(arguments: EmptyQuery())
        #expect(result.contains("Assets:Bank"))
        #expect(result.contains("€8198.21"))
        #expect(result.contains("Assets:Cash"))
    }

    @Test func assetsReturnsData() async throws {
        let tool = AssetsBreakdownTool(backend: backend)
        let result = try await tool.call(arguments: EmptyQuery())
        #expect(result.contains("Assets:Bank"))
        #expect(result.contains("8198.21"))
    }

    @Test func liabilitiesReturnsData() async throws {
        let tool = LiabilitiesBreakdownTool(backend: backend)
        let result = try await tool.call(arguments: EmptyQuery())
        #expect(result.contains("Liabilities:Mortgage"))
        #expect(result.contains("-150000"))
    }

    @Test func transactionSearchFindsLidl() async throws {
        let tool = TransactionSearchTool(backend: backend)
        let result = try await tool.call(arguments: TextQuery(text: "Lidl"))
        #expect(result.contains("Lidl"))
        #expect(result.contains("45.2"))
        #expect(result.contains("Found 1 transaction"))
    }

    @Test func transactionSearchEmptyResult() async throws {
        let tool = TransactionSearchTool(backend: backend)
        let result = try await tool.call(arguments: TextQuery(text: "nonexistent"))
        #expect(result.contains("No transactions found"))
    }
}

// MARK: - Commodity Style Tests

@Suite("CommodityStyle")
struct CommodityStyleTests {

    // -- Helpers --

    static let europeanStyle = AmountStyle(
        commoditySide: .left,
        commoditySpaced: false,
        decimalMark: ",",
        digitGroupSeparator: ".",
        digitGroupSizes: [3],
        precision: 2
    )

    static let usStyle = AmountStyle(
        commoditySide: .left,
        commoditySpaced: false,
        decimalMark: ".",
        digitGroupSeparator: ",",
        digitGroupSizes: [3],
        precision: 2
    )

    // -- Amount.formatted() with styles --

    @Test func formatDecimalEuropean() {
        let amount = Amount(commodity: "€", quantity: Decimal(string: "1000")!, style: CommodityStyleTests.europeanStyle)
        let result = amount.formatted()
        #expect(result == "€1.000,00")
    }

    @Test func formatDecimalUS() {
        let amount = Amount(commodity: "$", quantity: Decimal(string: "1000")!, style: CommodityStyleTests.usStyle)
        let result = amount.formatted()
        #expect(result == "$1,000.00")
    }

    @Test func formatDecimalNoGrouping() {
        // Default style: no grouping, dot decimal — backward compatibility
        let amount = Amount(commodity: "€", quantity: Decimal(string: "1000")!, style: .default)
        let result = amount.formatted()
        #expect(result == "€1000.00")
    }

    @Test func formatDecimalLargeEuropean() {
        let amount = Amount(commodity: "€", quantity: Decimal(string: "1234567.89")!, style: CommodityStyleTests.europeanStyle)
        let result = amount.formatted()
        #expect(result == "€1.234.567,89")
    }

    @Test func formatDecimalNegativeEuropean() {
        let amount = Amount(commodity: "€", quantity: Decimal(string: "-1500.50")!, style: CommodityStyleTests.europeanStyle)
        let result = amount.formatted()
        #expect(result == "-€1.500,50")
    }

    @Test func formatDecimalSmallEuropean() {
        // No grouping needed for small numbers
        let amount = Amount(commodity: "€", quantity: Decimal(string: "50")!, style: CommodityStyleTests.europeanStyle)
        let result = amount.formatted()
        #expect(result == "€50,00")
    }

    @Test func formatDecimalRightSideCommodity() {
        let style = AmountStyle(
            commoditySide: .right,
            commoditySpaced: true,
            decimalMark: ",",
            digitGroupSeparator: ".",
            digitGroupSizes: [3],
            precision: 2
        )
        let amount = Amount(commodity: "EUR", quantity: Decimal(string: "1000")!, style: style)
        let result = amount.formatted()
        #expect(result == "1.000,00 EUR")
    }

    // -- Roundtrip tests --

    @Test func roundtripEuropean() {
        let amount = Amount(commodity: "€", quantity: Decimal(string: "1500.75")!, style: CommodityStyleTests.europeanStyle)
        let formatted = amount.formatted()
        // €1.500,75
        let (qty, com) = AmountParser.parse(formatted)
        #expect(qty == Decimal(string: "1500.75"))
        #expect(com == "€")
    }

    @Test func roundtripUS() {
        let amount = Amount(commodity: "$", quantity: Decimal(string: "1500.75")!, style: CommodityStyleTests.usStyle)
        let formatted = amount.formatted()
        // $1,500.75
        let (qty, com) = AmountParser.parse(formatted)
        #expect(qty == Decimal(string: "1500.75"))
        #expect(com == "$")
    }

    @Test func roundtripNegativeEuropean() {
        let amount = Amount(commodity: "€", quantity: Decimal(string: "-2500")!, style: CommodityStyleTests.europeanStyle)
        let formatted = amount.formatted()
        let (qty, com) = AmountParser.parse(formatted)
        #expect(qty == Decimal(string: "-2500"))
        #expect(com == "€")
    }

    // -- Style extraction --

    @Test func styleExtractionFromTransactions() {
        let txns = [
            Transaction(
                index: 0, date: "2026-01-15", description: "Test",
                postings: [
                    Posting(account: "expenses:food", amounts: [
                        Amount(commodity: "€", quantity: 50, style: CommodityStyleTests.europeanStyle)
                    ]),
                    Posting(account: "assets:bank")
                ]
            )
        ]
        let styles = Self.extractStyles(from: txns)
        #expect(styles["€"]?.decimalMark == ",")
        #expect(styles["€"]?.digitGroupSeparator == ".")
        #expect(styles["€"]?.digitGroupSizes == [3])
    }

    @Test func styleExtractionPreservesFirstSeen() {
        let style1 = AmountStyle(commoditySide: .left, commoditySpaced: false, decimalMark: ",", precision: 2)
        let style2 = AmountStyle(commoditySide: .left, commoditySpaced: true, decimalMark: ",", precision: 4)
        let txns = [
            Transaction(index: 0, date: "2026-01-01", description: "T1",
                postings: [Posting(account: "a", amounts: [Amount(commodity: "€", quantity: 1, style: style1)])]),
            Transaction(index: 1, date: "2026-01-02", description: "T2",
                postings: [Posting(account: "b", amounts: [Amount(commodity: "€", quantity: 2, style: style2)])])
        ]
        let styles = Self.extractStyles(from: txns)
        // First style wins
        #expect(styles["€"]?.commoditySpaced == false)
        #expect(styles["€"]?.precision == 2)
    }

    @Test func styleExtractionIncludesCostCommodity() {
        let costStyle = AmountStyle(commoditySide: .left, decimalMark: ".", precision: 2)
        let amount = Amount(
            commodity: "XDWD", quantity: 10,
            style: AmountStyle(commoditySide: .right, commoditySpaced: true, decimalMark: ".", precision: 0),
            cost: CostAmount(commodity: "$", quantity: 500, style: costStyle)
        )
        let txns = [
            Transaction(index: 0, date: "2026-01-01", description: "Buy",
                postings: [Posting(account: "assets:investments", amounts: [amount])])
        ]
        let styles = Self.extractStyles(from: txns)
        #expect(styles["XDWD"] != nil)
        #expect(styles["$"] != nil)
        #expect(styles["$"]?.decimalMark == ".")
    }

    @Test func styleFallbackForUnknownCommodity() {
        let styles: [String: AmountStyle] = ["€": CommodityStyleTests.europeanStyle]
        let result = styles["BTC"] ?? .default
        #expect(result.decimalMark == ".")
    }

    // -- RecurringManager parse with styles --

    @Test func recurringParseWithEuropeanStyles() throws {
        let content = """
        ~ monthly from 2026-01-01  ; rule-id:test1 Test rule
            expenses:food                                    €500,00
            assets:bank

        """
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let tmpFile = tmpDir.appendingPathComponent("recurring.journal")
        try content.write(to: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let styles: [String: AmountStyle] = ["€": CommodityStyleTests.europeanStyle]
        let rules = RecurringManager.parseRules(recurringPath: tmpFile, commodityStyles: styles)

        #expect(rules.count == 1)
        let amount = rules[0].postings[0].amounts[0]
        #expect(amount.style.decimalMark == ",")
        #expect(amount.style.digitGroupSeparator == ".")
        // Verify formatted output uses European style
        let formatted = amount.formatted()
        #expect(formatted == "€500,00")
    }

    @Test func budgetParseWithEuropeanStyles() throws {
        let content = """
        ~ monthly
            expenses:groceries                               €500,00
            Assets:Budget

        """
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let tmpFile = tmpDir.appendingPathComponent("budget.journal")
        try content.write(to: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let styles: [String: AmountStyle] = ["€": CommodityStyleTests.europeanStyle]
        let rules = BudgetManager.parseRules(budgetPath: tmpFile, commodityStyles: styles)

        #expect(rules.count == 1)
        let amount = rules[0].amount
        #expect(amount.style.decimalMark == ",")
        let formatted = amount.formatted()
        #expect(formatted == "€500,00")
    }

    // -- Helper: replicate AppState.extractCommodityStyles() logic for testing --

    private static func extractStyles(from transactions: [Transaction]) -> [String: AmountStyle] {
        var styles: [String: AmountStyle] = [:]
        for txn in transactions {
            for posting in txn.postings {
                for amount in posting.amounts {
                    if !amount.commodity.isEmpty && styles[amount.commodity] == nil {
                        styles[amount.commodity] = amount.style
                    }
                    if let cost = amount.cost, !cost.commodity.isEmpty && styles[cost.commodity] == nil {
                        styles[cost.commodity] = cost.style
                    }
                }
            }
        }
        return styles
    }
}

// MARK: - Integration Tests (require hledger installed)

@Suite("Integration")
struct IntegrationTests {

    // -- Helpers --

    /// Path to the Fixtures directory, derived from the test source file location.
    private static let fixturesDir: URL = {
        let testFile = URL(fileURLWithPath: #filePath)
        return testFile.deletingLastPathComponent().appendingPathComponent("Fixtures")
    }()

    private static func fixturePath(_ name: String) -> URL {
        fixturesDir.appendingPathComponent(name)
    }

    /// Find hledger or skip the test.
    private static func requireHledger() throws -> String {
        guard let path = BinaryDetector.findHledger() else {
            throw HledgerNotFound()
        }
        return path
    }

    struct HledgerNotFound: Error {}

    /// Run hledger with the given arguments and return stdout.
    private static func runHledger(_ hledgerPath: String, args: [String]) async throws -> String {
        let runner = SubprocessRunner(executablePath: hledgerPath)
        return try await runner.run(args)
    }

    /// Parse hledger JSON output into transactions using the real HledgerBackend parser.
    private static func parseTransactionsFromJSON(_ json: String) throws -> [Transaction] {
        guard let data = json.data(using: .utf8) else {
            throw BackendError.parseError("Invalid UTF-8")
        }
        let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return jsonArray.map { HledgerBackend.parseTransaction($0) }
    }

    /// Extract commodity styles from transactions (same logic as AppState).
    private static func extractStyles(from transactions: [Transaction]) -> [String: AmountStyle] {
        var styles: [String: AmountStyle] = [:]
        for txn in transactions {
            for posting in txn.postings {
                for amount in posting.amounts {
                    if !amount.commodity.isEmpty && styles[amount.commodity] == nil {
                        styles[amount.commodity] = amount.style
                    }
                }
            }
        }
        return styles
    }

    // -- 1. Validate all fixtures --

    @Test func validateEuropeanFixture() async throws {
        let hledger = try Self.requireHledger()
        let output = try await Self.runHledger(hledger, args: ["--no-conf", "-f", Self.fixturePath("european.journal").path, "check"])
        _ = output // check passed (no exception thrown)
    }

    @Test func validateUSFixture() async throws {
        let hledger = try Self.requireHledger()
        _ = try await Self.runHledger(hledger, args: ["--no-conf", "-f", Self.fixturePath("us.journal").path, "check"])
    }

    @Test func validateSwissFixture() async throws {
        let hledger = try Self.requireHledger()
        _ = try await Self.runHledger(hledger, args: ["--no-conf", "-f", Self.fixturePath("swiss.journal").path, "check"])
    }

    @Test func validateIndianFixture() async throws {
        let hledger = try Self.requireHledger()
        _ = try await Self.runHledger(hledger, args: ["--no-conf", "-f", Self.fixturePath("indian.journal").path, "check"])
    }

    // -- 2. Parse styles from hledger JSON --

    @Test func parseEuropeanStyleFromHledger() async throws {
        let hledger = try Self.requireHledger()
        let json = try await Self.runHledger(hledger, args: [
            "--no-conf", "-f", Self.fixturePath("european.journal").path, "print", "-O", "json"
        ])
        let txns = try Self.parseTransactionsFromJSON(json)
        #expect(txns.count == 2)

        let styles = Self.extractStyles(from: txns)
        let euroStyle = try #require(styles["€"])
        #expect(euroStyle.decimalMark == ",")
        #expect(euroStyle.digitGroupSeparator == ".")
        #expect(euroStyle.digitGroupSizes == [3])
        #expect(euroStyle.commoditySide == .left)
        #expect(euroStyle.precision == 2)
    }

    @Test func parseUSStyleFromHledger() async throws {
        let hledger = try Self.requireHledger()
        let json = try await Self.runHledger(hledger, args: [
            "--no-conf", "-f", Self.fixturePath("us.journal").path, "print", "-O", "json"
        ])
        let txns = try Self.parseTransactionsFromJSON(json)
        let styles = Self.extractStyles(from: txns)
        let dollarStyle = try #require(styles["$"])
        #expect(dollarStyle.decimalMark == ".")
        #expect(dollarStyle.digitGroupSeparator == ",")
        #expect(dollarStyle.digitGroupSizes == [3])
    }

    @Test func parseSwissStyleFromHledger() async throws {
        let hledger = try Self.requireHledger()
        let json = try await Self.runHledger(hledger, args: [
            "--no-conf", "-f", Self.fixturePath("swiss.journal").path, "print", "-O", "json"
        ])
        let txns = try Self.parseTransactionsFromJSON(json)
        let styles = Self.extractStyles(from: txns)
        let chfStyle = try #require(styles["CHF"])
        #expect(chfStyle.decimalMark == ".")
        #expect(chfStyle.digitGroupSeparator == " ")
        #expect(chfStyle.commoditySpaced == true)
        #expect(chfStyle.commoditySide == .left)
    }

    @Test func parseIndianStyleFromHledger() async throws {
        let hledger = try Self.requireHledger()
        let json = try await Self.runHledger(hledger, args: [
            "--no-conf", "-f", Self.fixturePath("indian.journal").path, "print", "-O", "json"
        ])
        let txns = try Self.parseTransactionsFromJSON(json)
        let styles = Self.extractStyles(from: txns)
        let rupeeStyle = try #require(styles["₹"])
        #expect(rupeeStyle.decimalMark == ".")
        #expect(rupeeStyle.digitGroupSeparator == ",")
        #expect(rupeeStyle.digitGroupSizes == [3, 2])
    }

    // -- 3. Roundtrip: extract style → create Amount → format → write → hledger validates --

    @Test func roundtripWriteEuropean() async throws {
        let hledger = try Self.requireHledger()

        // 1. Extract style from European fixture
        let json = try await Self.runHledger(hledger, args: [
            "--no-conf", "-f", Self.fixturePath("european.journal").path, "print", "-O", "json"
        ])
        let txns = try Self.parseTransactionsFromJSON(json)
        let euroStyle = try #require(Self.extractStyles(from: txns)["€"])

        // 2. Create a new transaction with correct style
        let amount = Amount(commodity: "€", quantity: Decimal(string: "1000")!, style: euroStyle)
        let txn = Transaction(
            index: 0, date: "2026-06-01", description: "Test roundtrip",
            postings: [
                Posting(account: "expenses:test", amounts: [amount]),
                Posting(account: "assets:bank")
            ], status: .cleared
        )
        let formatted = TransactionFormatter.format(txn)

        // 3. Write to temp file that includes the European fixture (for commodity context)
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let tmpJournal = tmpDir.appendingPathComponent("test.journal")
        let content = "include \(Self.fixturePath("european.journal").path)\n\n\(formatted)\n"
        try content.write(to: tmpJournal, atomically: true, encoding: .utf8)

        // 4. hledger check must pass
        _ = try await Self.runHledger(hledger, args: ["--no-conf", "-f", tmpJournal.path, "check"])

        // 5. Verify hledger reads the amount correctly (1000, not 100000)
        let verifyJSON = try await Self.runHledger(hledger, args: [
            "--no-conf", "-f", tmpJournal.path, "print", "-O", "json", "desc:Test roundtrip"
        ])
        let verifyTxns = try Self.parseTransactionsFromJSON(verifyJSON)
        #expect(verifyTxns.count == 1)
        let verifyAmount = verifyTxns[0].postings[0].amounts[0]
        #expect(verifyAmount.quantity == Decimal(string: "1000"))
    }

    @Test func roundtripWriteUS() async throws {
        let hledger = try Self.requireHledger()

        let json = try await Self.runHledger(hledger, args: [
            "--no-conf", "-f", Self.fixturePath("us.journal").path, "print", "-O", "json"
        ])
        let txns = try Self.parseTransactionsFromJSON(json)
        let dollarStyle = try #require(Self.extractStyles(from: txns)["$"])

        let amount = Amount(commodity: "$", quantity: Decimal(string: "2500.50")!, style: dollarStyle)
        let txn = Transaction(
            index: 0, date: "2026-06-01", description: "Test roundtrip US",
            postings: [
                Posting(account: "expenses:test", amounts: [amount]),
                Posting(account: "assets:bank")
            ], status: .cleared
        )
        let formatted = TransactionFormatter.format(txn)

        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let tmpJournal = tmpDir.appendingPathComponent("test.journal")
        let content = "include \(Self.fixturePath("us.journal").path)\n\n\(formatted)\n"
        try content.write(to: tmpJournal, atomically: true, encoding: .utf8)

        _ = try await Self.runHledger(hledger, args: ["--no-conf", "-f", tmpJournal.path, "check"])

        let verifyJSON = try await Self.runHledger(hledger, args: [
            "--no-conf", "-f", tmpJournal.path, "print", "-O", "json", "desc:Test roundtrip US"
        ])
        let verifyTxns = try Self.parseTransactionsFromJSON(verifyJSON)
        #expect(verifyTxns.count == 1)
        #expect(verifyTxns[0].postings[0].amounts[0].quantity == Decimal(string: "2500.5"))
    }

    // -- 4. Bug #56 reproduction: prove the fix works --

    @Test func bug56ReproductionDefaultStyleCausesWrongValue() async throws {
        let hledger = try Self.requireHledger()

        // Write €1000 with DEFAULT style (decimalMark: ".") into a European journal
        // This is the exact bug: "€1000.00" in a journal with "€1.000,00" format
        let buggyAmount = Amount(commodity: "€", quantity: Decimal(string: "1000")!, style: .default)
        let buggyFormatted = buggyAmount.formatted()
        #expect(buggyFormatted == "€1000.00") // This is what the old code produced

        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let tmpJournal = tmpDir.appendingPathComponent("bug56.journal")
        let content = """
        include \(Self.fixturePath("european.journal").path)

        2026-06-01 * Bug 56 test
            expenses:test                                    \(buggyFormatted)
            assets:bank

        """
        try content.write(to: tmpJournal, atomically: true, encoding: .utf8)

        // hledger reads €1000.00 as €100000 in European context (dot = thousands)
        let json = try await Self.runHledger(hledger, args: [
            "--no-conf", "-f", tmpJournal.path, "print", "-O", "json", "desc:Bug 56"
        ])
        let txns = try Self.parseTransactionsFromJSON(json)
        #expect(txns.count == 1)
        let badValue = txns[0].postings[0].amounts[0].quantity
        // hledger interprets "1000.00" as 100000 (dot is thousands separator)
        #expect(badValue == Decimal(string: "100000"))
    }

    @Test func bug56FixCorrectStyleProducesCorrectValue() async throws {
        let hledger = try Self.requireHledger()

        // Extract the real European style from hledger
        let json = try await Self.runHledger(hledger, args: [
            "--no-conf", "-f", Self.fixturePath("european.journal").path, "print", "-O", "json"
        ])
        let txns = try Self.parseTransactionsFromJSON(json)
        let euroStyle = try #require(Self.extractStyles(from: txns)["€"])

        // Write €1000 with CORRECT European style
        let fixedAmount = Amount(commodity: "€", quantity: Decimal(string: "1000")!, style: euroStyle)
        let fixedFormatted = fixedAmount.formatted()
        #expect(fixedFormatted == "€1.000,00") // Correct European format

        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let tmpJournal = tmpDir.appendingPathComponent("bug56_fixed.journal")
        let content = """
        include \(Self.fixturePath("european.journal").path)

        2026-06-01 * Bug 56 fixed
            expenses:test                                    \(fixedFormatted)
            assets:bank

        """
        try content.write(to: tmpJournal, atomically: true, encoding: .utf8)

        // Verify hledger reads the correct value
        let verifyJSON = try await Self.runHledger(hledger, args: [
            "--no-conf", "-f", tmpJournal.path, "print", "-O", "json", "desc:Bug 56 fixed"
        ])
        let verifyTxns = try Self.parseTransactionsFromJSON(verifyJSON)
        #expect(verifyTxns.count == 1)
        let correctValue = verifyTxns[0].postings[0].amounts[0].quantity
        #expect(correctValue == Decimal(string: "1000"))
    }
}

// MARK: - PriceFetcher Tests

@Suite("PriceFetcher")
struct PriceFetcherTests {
    @Test func parsesLastLineFromMultiDayOutput() {
        let output = """
        P 2026-04-02 00:00:00 XEON 5.12 EUR
        P 2026-04-03 00:00:00 XEON 5.15 EUR
        P 2026-04-04 00:00:00 XEON 5.18 EUR
        """
        let result = PriceFetcher.parseLatestDirective(from: output)
        #expect(result == "P 2026-04-04 XEON 5.18 EUR")
    }

    @Test func parsesOnlyLineWhenSingleTradingDay() {
        let output = "P 2026-04-04 00:00:00 SWDA 112.73999786 EUR\n"
        let result = PriceFetcher.parseLatestDirective(from: output)
        #expect(result == "P 2026-04-04 SWDA 112.74 EUR")
    }

    @Test func returnsNilForEmptyOutput() {
        #expect(PriceFetcher.parseLatestDirective(from: "") == nil)
        #expect(PriceFetcher.parseLatestDirective(from: "   \n  \n") == nil)
    }

    @Test func cleansTimestamp() {
        let result = PriceFetcher.cleanPDirective("P 2026-04-04 00:00:00 XEON 5.18345 EUR")
        #expect(result == "P 2026-04-04 XEON 5.18 EUR")
    }

    @Test func cleansRoundsPrice() {
        let result = PriceFetcher.cleanPDirective("P 2026-04-04 XEON 5.18999 EUR")
        #expect(result == "P 2026-04-04 XEON 5.19 EUR")
    }

    @Test func cleansLineWithoutTimestamp() {
        let result = PriceFetcher.cleanPDirective("P 2026-04-04 XEON 5.18 EUR")
        #expect(result == "P 2026-04-04 XEON 5.18 EUR")
    }
}
