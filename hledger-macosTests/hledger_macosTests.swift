import Testing
import Foundation
@testable import hledger_macos

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
    func loadExpenseBreakdown(period: String?) async throws -> [(String, Decimal, String)] {
        [("Expenses:School", 407, "€"), ("Expenses:Groceries", 319.17, "€")]
    }
    func loadIncomeBreakdown(period: String?) async throws -> [(String, Decimal, String)] {
        [("Income:Salary", 7302, "€"), ("Income:Other", 39.75, "€")]
    }
    func loadLiabilitiesBreakdown() async throws -> [(String, Decimal, String)] {
        [("Liabilities:Mortgage", -150000, "€")]
    }
    func loadAssetsBreakdown() async throws -> [(String, Decimal, String)] {
        [("Assets:Bank", 8198.21, "€"), ("Assets:Cash", 153.40, "€")]
    }
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
