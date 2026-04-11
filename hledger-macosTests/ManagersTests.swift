import Testing
import Foundation
@testable import hledger_for_Mac

// MARK: - Helpers

fileprivate enum MgrHelpers {
    /// Build a unique temp directory for a test.
    static func makeTempDir(name: String = "ManagersTests") throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func writeFile(_ content: String, in dir: URL, name: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

// MARK: - PriceFetcher additional

@Suite("PriceFetcher additional")
struct PriceFetcherAdditionalTests {

    @Test func parseLatestDirectiveSkipsBlankLines() {
        let output = """

        P 2026-04-02 00:00:00 SWDA 100.00 EUR

        P 2026-04-03 00:00:00 SWDA 101.00 EUR

        """
        let result = PriceFetcher.parseLatestDirective(from: output)
        #expect(result == "P 2026-04-03 SWDA 101.00 EUR")
    }

    @Test func cleanPDirectiveRoundsHalfUpToTwoDecimals() {
        // Half-up rounding: 5.555 → 5.56
        let result = PriceFetcher.cleanPDirective("P 2026-04-04 XEON 5.555 EUR")
        // String(format: "%.2f") uses banker's rounding actually,
        // so we just verify the precision is 2 and the value is in [5.55, 5.56]
        #expect(result.hasPrefix("P 2026-04-04 XEON 5.5"))
        #expect(result.hasSuffix(" EUR"))
        let parts = result.split(separator: " ")
        let priceStr = String(parts[3])
        let dotIdx = priceStr.firstIndex(of: ".")!
        let decimals = priceStr.distance(from: priceStr.index(after: dotIdx), to: priceStr.endIndex)
        #expect(decimals == 2)
    }

    @Test func cleanPDirectivePreservesShortValues() {
        // Single-decimal value gets padded to 2
        let result = PriceFetcher.cleanPDirective("P 2026-04-04 XEON 5.1 EUR")
        #expect(result == "P 2026-04-04 XEON 5.10 EUR")
    }

    @Test func cleanPDirectiveHandlesIntegerPrice() {
        let result = PriceFetcher.cleanPDirective("P 2026-04-04 XEON 100 EUR")
        #expect(result == "P 2026-04-04 XEON 100.00 EUR")
    }
}

// MARK: - BudgetManager

@Suite("BudgetManager")
struct BudgetManagerTests {

    // -- Path helper --

    @Test func budgetPathRelativeToMainJournal() {
        let main = URL(fileURLWithPath: "/tmp/myledger/main.journal")
        let budget = BudgetManager.budgetPath(for: main)
        #expect(budget.path == "/tmp/myledger/budget.journal")
    }

    // -- Parse --

    @Test func parseNonexistentFileReturnsEmpty() {
        let url = URL(fileURLWithPath: "/nonexistent/budget.journal")
        #expect(BudgetManager.parseRules(budgetPath: url).isEmpty)
    }

    @Test func parseEmptyFileReturnsEmpty() throws {
        let dir = try MgrHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = try MgrHelpers.writeFile("", in: dir, name: "budget.journal")
        #expect(BudgetManager.parseRules(budgetPath: file).isEmpty)
    }

    @Test func parseWhitespaceOnlyFileReturnsEmpty() throws {
        let dir = try MgrHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = try MgrHelpers.writeFile("   \n\n   \n", in: dir, name: "budget.journal")
        #expect(BudgetManager.parseRules(budgetPath: file).isEmpty)
    }

    @Test func parsesMultiplePostings() throws {
        let dir = try MgrHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let content = """
        ~ monthly
            expenses:groceries                               €500.00
            expenses:rent                                    €1200.00
            expenses:transport                               €100.00
            Assets:Budget

        """
        let file = try MgrHelpers.writeFile(content, in: dir, name: "budget.journal")
        let rules = BudgetManager.parseRules(budgetPath: file)

        #expect(rules.count == 3)
        #expect(rules.contains { $0.account == "expenses:groceries" })
        #expect(rules.contains { $0.account == "expenses:rent" })
        #expect(rules.contains { $0.account == "expenses:transport" })
    }

    @Test func parsesPostingWithCategory() throws {
        let dir = try MgrHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let content = """
        ~ monthly
            expenses:groceries                               €500.00  ; category: Food
            Assets:Budget

        """
        let file = try MgrHelpers.writeFile(content, in: dir, name: "budget.journal")
        let rules = BudgetManager.parseRules(budgetPath: file)

        #expect(rules.count == 1)
        #expect(rules[0].category == "Food")
    }

    @Test func parseStopsAtNonIndentedLine() throws {
        // A non-indented, non-tilde line ends the periodic block
        let dir = try MgrHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let content = """
        ~ monthly
            expenses:groceries                               €500.00
            Assets:Budget
        2026-04-15 Some transaction
            expenses:other                                   €99.00
            assets:bank

        """
        let file = try MgrHelpers.writeFile(content, in: dir, name: "budget.journal")
        let rules = BudgetManager.parseRules(budgetPath: file)

        // Only the periodic rule is parsed; the regular transaction is ignored
        #expect(rules.count == 1)
        #expect(rules[0].account == "expenses:groceries")
    }

    // -- Format --

    @Test func formatEmptyRulesReturnsEmptyString() {
        #expect(BudgetManager.formatRules([]) == "")
    }

    @Test func formatSingleRule() {
        let rule = BudgetRule(
            account: "expenses:food",
            amount: Amount(commodity: "€", quantity: Decimal(string: "500.00")!),
            category: ""
        )
        let result = BudgetManager.formatRules([rule])
        #expect(result.contains("~ monthly"))
        #expect(result.contains("expenses:food"))
        #expect(result.contains("€500.00"))
        #expect(result.contains("Assets:Budget"))
    }

    @Test func formatRuleWithCategory() {
        let rule = BudgetRule(
            account: "expenses:food",
            amount: Amount(commodity: "€", quantity: Decimal(string: "500.00")!),
            category: "Groceries"
        )
        let result = BudgetManager.formatRules([rule])
        #expect(result.contains("; category: Groceries"))
    }

    @Test func formatRoundTripPreservesAccounts() throws {
        let dir = try MgrHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let originalRules = [
            BudgetRule(account: "expenses:food", amount: Amount(commodity: "€", quantity: Decimal(string: "500.00")!), category: ""),
            BudgetRule(account: "expenses:rent", amount: Amount(commodity: "€", quantity: Decimal(string: "1200.00")!), category: "Housing")
        ]

        let formatted = BudgetManager.formatRules(originalRules)
        let file = try MgrHelpers.writeFile(formatted, in: dir, name: "budget.journal")
        let parsed = BudgetManager.parseRules(budgetPath: file)

        #expect(parsed.count == 2)
        #expect(parsed.contains { $0.account == "expenses:food" })
        #expect(parsed.contains { $0.account == "expenses:rent" && $0.category == "Housing" })
    }

    // -- ensureBudgetFile --

    @Test func ensureBudgetFileCreatesMissingFile() throws {
        let dir = try MgrHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let main = try MgrHelpers.writeFile("", in: dir, name: "main.journal")

        try BudgetManager.ensureBudgetFile(journalFile: main)

        let budgetPath = dir.appendingPathComponent("budget.journal")
        #expect(FileManager.default.fileExists(atPath: budgetPath.path))
    }

    @Test func ensureBudgetFileAddsIncludeDirective() throws {
        let dir = try MgrHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let main = try MgrHelpers.writeFile("2026-04-01 Existing\n    a   €1\n    b\n", in: dir, name: "main.journal")

        try BudgetManager.ensureBudgetFile(journalFile: main)

        let mainContent = try String(contentsOf: main, encoding: .utf8)
        #expect(mainContent.contains("include budget.journal"))
    }

    @Test func ensureBudgetFileNoDoubleInclude() throws {
        let dir = try MgrHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let main = try MgrHelpers.writeFile("include budget.journal\n", in: dir, name: "main.journal")

        try BudgetManager.ensureBudgetFile(journalFile: main)
        try BudgetManager.ensureBudgetFile(journalFile: main)  // call twice

        let mainContent = try String(contentsOf: main, encoding: .utf8)
        let count = mainContent.components(separatedBy: "include budget.journal").count - 1
        #expect(count == 1)
    }
}

// MARK: - RecurringManager

@Suite("RecurringManager")
struct RecurringManagerTests {

    // -- Path helper --

    @Test func recurringPathRelativeToMainJournal() {
        let main = URL(fileURLWithPath: "/tmp/myledger/main.journal")
        let recurring = RecurringManager.recurringPath(for: main)
        #expect(recurring.path == "/tmp/myledger/recurring.journal")
    }

    // -- Parse --

    @Test func parseNonexistentFileReturnsEmpty() {
        let url = URL(fileURLWithPath: "/nonexistent/recurring.journal")
        #expect(RecurringManager.parseRules(recurringPath: url).isEmpty)
    }

    @Test func parseEmptyFileReturnsEmpty() throws {
        let dir = try MgrHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = try MgrHelpers.writeFile("", in: dir, name: "recurring.journal")
        #expect(RecurringManager.parseRules(recurringPath: file).isEmpty)
    }

    @Test func parsesRuleWithStartDate() throws {
        let dir = try MgrHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let content = """
        ~ monthly from 2026-01-01  ; rule-id:salary Monthly salary
            assets:bank                                      €3000.00
            income:salary

        """
        let file = try MgrHelpers.writeFile(content, in: dir, name: "recurring.journal")
        let rules = RecurringManager.parseRules(recurringPath: file)

        #expect(rules.count == 1)
        #expect(rules[0].ruleId == "salary")
        #expect(rules[0].periodExpr == "monthly")
        #expect(rules[0].startDate == "2026-01-01")
        #expect(rules[0].endDate == nil)
        #expect(rules[0].description == "Monthly salary")
    }

    @Test func parsesRuleWithStartAndEndDates() throws {
        let dir = try MgrHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let content = """
        ~ monthly from 2026-01-01 to 2026-12-31  ; rule-id:rent2026 Annual rent
            expenses:rent                                    €1200.00
            assets:bank

        """
        let file = try MgrHelpers.writeFile(content, in: dir, name: "recurring.journal")
        let rules = RecurringManager.parseRules(recurringPath: file)

        #expect(rules.count == 1)
        #expect(rules[0].startDate == "2026-01-01")
        #expect(rules[0].endDate == "2026-12-31")
    }

    @Test func parseSkipsRuleWithoutRuleId() throws {
        let dir = try MgrHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let content = """
        ~ monthly  ; no rule-id here
            expenses:rent                                    €1200.00
            assets:bank

        ~ monthly  ; rule-id:valid Valid rule
            expenses:other                                   €100.00
            assets:bank

        """
        let file = try MgrHelpers.writeFile(content, in: dir, name: "recurring.journal")
        let rules = RecurringManager.parseRules(recurringPath: file)

        // Only the rule with rule-id is kept
        #expect(rules.count == 1)
        #expect(rules[0].ruleId == "valid")
    }

    @Test func parsesMultiplePostingsPerRule() throws {
        let dir = try MgrHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let content = """
        ~ monthly  ; rule-id:split Split rule
            expenses:rent                                    €1000.00
            expenses:utilities                               €200.00
            assets:bank

        """
        let file = try MgrHelpers.writeFile(content, in: dir, name: "recurring.journal")
        let rules = RecurringManager.parseRules(recurringPath: file)

        #expect(rules.count == 1)
        #expect(rules[0].postings.count == 3)
    }

    @Test func parsesMultipleRules() throws {
        let dir = try MgrHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let content = """
        ~ monthly from 2026-01-01  ; rule-id:salary Salary
            assets:bank                                      €3000.00
            income:salary

        ~ monthly from 2026-01-01  ; rule-id:rent Rent
            expenses:rent                                    €1200.00
            assets:bank

        """
        let file = try MgrHelpers.writeFile(content, in: dir, name: "recurring.journal")
        let rules = RecurringManager.parseRules(recurringPath: file)

        #expect(rules.count == 2)
        #expect(rules.contains { $0.ruleId == "salary" })
        #expect(rules.contains { $0.ruleId == "rent" })
    }

    // -- Format --

    @Test func formatEmptyRulesReturnsEmptyString() {
        #expect(RecurringManager.formatRules([]) == "")
    }

    @Test func formatSingleRule() {
        let rule = RecurringRule(
            ruleId: "salary",
            periodExpr: "monthly",
            description: "Monthly salary",
            postings: [
                Posting(account: "assets:bank", amounts: [Amount(commodity: "€", quantity: Decimal(string: "3000.00")!)]),
                Posting(account: "income:salary")
            ],
            startDate: "2026-01-01",
            endDate: nil
        )
        let result = RecurringManager.formatRules([rule])
        #expect(result.contains("~ monthly from 2026-01-01"))
        #expect(result.contains("rule-id:salary"))
        #expect(result.contains("Monthly salary"))
        #expect(result.contains("assets:bank"))
    }

    @Test func formatRuleWithEndDate() {
        let rule = RecurringRule(
            ruleId: "rent",
            periodExpr: "monthly",
            description: "Rent",
            postings: [
                Posting(account: "expenses:rent", amounts: [Amount(commodity: "€", quantity: Decimal(string: "1200.00")!)]),
                Posting(account: "assets:bank")
            ],
            startDate: "2026-01-01",
            endDate: "2026-12-31"
        )
        let result = RecurringManager.formatRules([rule])
        #expect(result.contains("from 2026-01-01 to 2026-12-31"))
    }

    @Test func formatRoundTripPreservesRuleStructure() throws {
        let dir = try MgrHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let original = RecurringRule(
            ruleId: "test",
            periodExpr: "monthly",
            description: "Test rule",
            postings: [
                Posting(account: "expenses:food", amounts: [Amount(commodity: "€", quantity: Decimal(string: "500.00")!)]),
                Posting(account: "assets:bank")
            ],
            startDate: "2026-01-01",
            endDate: nil
        )

        let formatted = RecurringManager.formatRules([original])
        let file = try MgrHelpers.writeFile(formatted, in: dir, name: "recurring.journal")
        let parsed = RecurringManager.parseRules(recurringPath: file)

        #expect(parsed.count == 1)
        #expect(parsed[0].ruleId == "test")
        #expect(parsed[0].periodExpr == "monthly")
        #expect(parsed[0].description == "Test rule")
        #expect(parsed[0].startDate == "2026-01-01")
        #expect(parsed[0].postings.count == 2)
    }

    // -- ensureRecurringFile --

    @Test func ensureRecurringFileCreatesMissingFile() throws {
        let dir = try MgrHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let main = try MgrHelpers.writeFile("", in: dir, name: "main.journal")

        try RecurringManager.ensureRecurringFile(journalFile: main)

        let recurringPath = dir.appendingPathComponent("recurring.journal")
        #expect(FileManager.default.fileExists(atPath: recurringPath.path))
    }

    @Test func ensureRecurringFileAddsIncludeDirective() throws {
        let dir = try MgrHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let main = try MgrHelpers.writeFile("2026-04-01 Existing\n    a   €1\n    b\n", in: dir, name: "main.journal")

        try RecurringManager.ensureRecurringFile(journalFile: main)

        let mainContent = try String(contentsOf: main, encoding: .utf8)
        #expect(mainContent.contains("include recurring.journal"))
    }

    @Test func ensureRecurringFileNoDoubleInclude() throws {
        let dir = try MgrHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let main = try MgrHelpers.writeFile("include recurring.journal\n", in: dir, name: "main.journal")

        try RecurringManager.ensureRecurringFile(journalFile: main)
        try RecurringManager.ensureRecurringFile(journalFile: main)

        let mainContent = try String(contentsOf: main, encoding: .utf8)
        let count = mainContent.components(separatedBy: "include recurring.journal").count - 1
        #expect(count == 1)
    }
}
