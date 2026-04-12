import Testing
import Foundation
@testable import hledger_for_Mac

// MARK: - Test helpers

fileprivate enum RFMHelpers {
    static func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RuleFileManagerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func writeFile(_ content: String, in dir: URL, name: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func makeBudgetRule(account: String = "expenses:food", amount: String = "500.00") -> BudgetRule {
        BudgetRule(
            account: account,
            amount: Amount(commodity: "€", quantity: Decimal(string: amount)!)
        )
    }
}

/// Backend that always passes validation.
fileprivate struct PassingBackend: AccountingBackend {
    var binaryPath: String { "/usr/bin/hledger" }
    var journalFile: URL { URL(fileURLWithPath: "/tmp/test.journal") }
    func validateJournal() async throws {}
    func version() async throws -> String { "1.0" }
    func loadTransactions(query: String?, reversed: Bool) async throws -> [Transaction] { [] }
    func loadDescriptions() async throws -> [String] { [] }
    func loadAccounts() async throws -> [String] { [] }
    func loadAccountBalances() async throws -> [(String, String)] { [] }
    func loadAccountTreeBalances() async throws -> [AccountNode] { [] }
    func loadCommodities() async throws -> [String] { [] }
    func loadJournalStats() async throws -> JournalStats { JournalStats(transactionCount: 0, accountCount: 0, commodities: []) }
    func loadPeriodSummary(period: String?) async throws -> PeriodSummary { PeriodSummary(income: 0, expenses: 0, commodity: "€") }
    func loadExpenseBreakdown(period: String?, preferredCommodity: String) async throws -> [(String, Decimal, String)] { [] }
    func loadIncomeBreakdown(period: String?, preferredCommodity: String) async throws -> [(String, Decimal, String)] { [] }
    func loadLiabilitiesBreakdown(preferredCommodity: String) async throws -> [(String, Decimal, String)] { [] }
    func loadAssetsBreakdown(preferredCommodity: String) async throws -> [(String, Decimal, String)] { [] }
    func loadMultiCurrencyAccounts() async throws -> Set<String> { [] }
    func loadInvestmentPositions() async throws -> [(String, Decimal, String)] { [] }
    func loadInvestmentCost() async throws -> [String: (Decimal, String)] { [:] }
    func loadInvestmentMarketValues(pricesFile: URL) async throws -> [String: (Decimal, String)] { [:] }
    func loadReport(type: ReportType, periodBegin: String?, periodEnd: String?, commodity: String?) async throws -> ReportData { ReportData(title: "") }
    func loadBudgetReport(period: String) async throws -> [BudgetRow] { [] }
    func parseCsvImport(csvFile: URL, rulesFile: URL) async throws -> [Transaction] { [] }
    func validateCsvRules(csvFile: URL, rulesFile: URL) async throws {}
    func appendTransaction(_ transaction: Transaction) async throws {}
    func updateTransactionStatus(_ transaction: Transaction, to newStatus: TransactionStatus) async throws {}
    func replaceTransaction(_ original: Transaction, with new: Transaction) async throws {}
    func deleteTransaction(_ transaction: Transaction) async throws {}
}

/// Backend that always rejects validation.
fileprivate struct RejectingBackend: AccountingBackend {
    var binaryPath: String { "/usr/bin/hledger" }
    var journalFile: URL { URL(fileURLWithPath: "/tmp/test.journal") }
    func validateJournal() async throws { throw BackendError.commandFailed("invalid journal") }
    func version() async throws -> String { "1.0" }
    func loadTransactions(query: String?, reversed: Bool) async throws -> [Transaction] { [] }
    func loadDescriptions() async throws -> [String] { [] }
    func loadAccounts() async throws -> [String] { [] }
    func loadAccountBalances() async throws -> [(String, String)] { [] }
    func loadAccountTreeBalances() async throws -> [AccountNode] { [] }
    func loadCommodities() async throws -> [String] { [] }
    func loadJournalStats() async throws -> JournalStats { JournalStats(transactionCount: 0, accountCount: 0, commodities: []) }
    func loadPeriodSummary(period: String?) async throws -> PeriodSummary { PeriodSummary(income: 0, expenses: 0, commodity: "€") }
    func loadExpenseBreakdown(period: String?, preferredCommodity: String) async throws -> [(String, Decimal, String)] { [] }
    func loadIncomeBreakdown(period: String?, preferredCommodity: String) async throws -> [(String, Decimal, String)] { [] }
    func loadLiabilitiesBreakdown(preferredCommodity: String) async throws -> [(String, Decimal, String)] { [] }
    func loadAssetsBreakdown(preferredCommodity: String) async throws -> [(String, Decimal, String)] { [] }
    func loadMultiCurrencyAccounts() async throws -> Set<String> { [] }
    func loadInvestmentPositions() async throws -> [(String, Decimal, String)] { [] }
    func loadInvestmentCost() async throws -> [String: (Decimal, String)] { [:] }
    func loadInvestmentMarketValues(pricesFile: URL) async throws -> [String: (Decimal, String)] { [:] }
    func loadReport(type: ReportType, periodBegin: String?, periodEnd: String?, commodity: String?) async throws -> ReportData { ReportData(title: "") }
    func loadBudgetReport(period: String) async throws -> [BudgetRow] { [] }
    func parseCsvImport(csvFile: URL, rulesFile: URL) async throws -> [Transaction] { [] }
    func validateCsvRules(csvFile: URL, rulesFile: URL) async throws {}
    func appendTransaction(_ transaction: Transaction) async throws {}
    func updateTransactionStatus(_ transaction: Transaction, to newStatus: TransactionStatus) async throws {}
    func replaceTransaction(_ original: Transaction, with new: Transaction) async throws {}
    func deleteTransaction(_ transaction: Transaction) async throws {}
}

// MARK: - RuleFileManager shared workflow tests

@Suite("RuleFileManager shared workflow")
struct RuleFileManagerTests {

    // MARK: writeRules — success path

    @Test func writeRulesWritesExpectedContent() async throws {
        let dir = try RFMHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try RFMHelpers.writeFile("", in: dir, name: "main.journal")
        let budgetPath = RuleFileManager<BudgetRuleFile>.filePath(for: main)
        try "".write(to: budgetPath, atomically: true, encoding: .utf8)

        let rule = RFMHelpers.makeBudgetRule()
        let rules = [rule]

        try await RuleFileManager<BudgetRuleFile>.writeRules(
            rules, to: budgetPath, journalFile: main, validator: PassingBackend()
        )

        let written = try String(contentsOf: budgetPath, encoding: .utf8)
        #expect(written.contains("expenses:food"))
        #expect(written.contains("€500.00"))
    }

    @Test func writeRulesRemovesBackupOnSuccess() async throws {
        let dir = try RFMHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try RFMHelpers.writeFile("", in: dir, name: "main.journal")
        let budgetPath = RuleFileManager<BudgetRuleFile>.filePath(for: main)
        try "".write(to: budgetPath, atomically: true, encoding: .utf8)

        try await RuleFileManager<BudgetRuleFile>.writeRules(
            [RFMHelpers.makeBudgetRule()], to: budgetPath, journalFile: main, validator: PassingBackend()
        )

        let backupPath = budgetPath.appendingPathExtension("bak")
        #expect(!FileManager.default.fileExists(atPath: backupPath.path))
    }

    // MARK: writeRules — rollback on validation failure

    @Test func writeRulesRollsBackOriginalContentOnFailure() async throws {
        let dir = try RFMHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try RFMHelpers.writeFile("", in: dir, name: "main.journal")
        let budgetPath = RuleFileManager<BudgetRuleFile>.filePath(for: main)
        let originalContent = "~ monthly\n    expenses:food                            €100.00\n    Assets:Budget\n"
        try originalContent.write(to: budgetPath, atomically: true, encoding: .utf8)

        let newRule = RFMHelpers.makeBudgetRule(account: "expenses:invalid", amount: "999.00")
        await #expect(throws: (any Error).self) {
            try await RuleFileManager<BudgetRuleFile>.writeRules(
                [newRule], to: budgetPath, journalFile: main, validator: RejectingBackend()
            )
        }

        let restoredContent = try String(contentsOf: budgetPath, encoding: .utf8)
        #expect(restoredContent == originalContent)
    }

    @Test func writeRulesRemovesBackupAfterRollback() async throws {
        let dir = try RFMHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try RFMHelpers.writeFile("", in: dir, name: "main.journal")
        let budgetPath = RuleFileManager<BudgetRuleFile>.filePath(for: main)
        try "~ monthly\n    Assets:Budget\n".write(to: budgetPath, atomically: true, encoding: .utf8)

        try? await RuleFileManager<BudgetRuleFile>.writeRules(
            [RFMHelpers.makeBudgetRule()], to: budgetPath, journalFile: main, validator: RejectingBackend()
        )

        let backupPath = budgetPath.appendingPathExtension("bak")
        #expect(!FileManager.default.fileExists(atPath: backupPath.path))
    }

    // MARK: addRule

    @Test func addRuleCreatesFileAndPersistsRule() async throws {
        let dir = try RFMHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try RFMHelpers.writeFile("", in: dir, name: "main.journal")
        let rule = RFMHelpers.makeBudgetRule(account: "expenses:rent", amount: "1200.00")

        try await RuleFileManager<BudgetRuleFile>.addRule(rule, journalFile: main, validator: PassingBackend())

        let path = RuleFileManager<BudgetRuleFile>.filePath(for: main)
        let parsed = RuleFileManager<BudgetRuleFile>.parseRules(at: path)
        #expect(parsed.count == 1)
        #expect(parsed[0].account == "expenses:rent")
    }

    @Test func addRuleDuplicateKeyThrows() async throws {
        let dir = try RFMHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try RFMHelpers.writeFile("", in: dir, name: "main.journal")
        let rule = RFMHelpers.makeBudgetRule(account: "expenses:food")

        try await RuleFileManager<BudgetRuleFile>.addRule(rule, journalFile: main, validator: PassingBackend())

        await #expect(throws: (any Error).self) {
            try await RuleFileManager<BudgetRuleFile>.addRule(rule, journalFile: main, validator: PassingBackend())
        }
    }

    // MARK: updateRule

    @Test func updateRuleReplacesExistingRule() async throws {
        let dir = try RFMHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try RFMHelpers.writeFile("", in: dir, name: "main.journal")
        let original = RFMHelpers.makeBudgetRule(account: "expenses:food", amount: "500.00")
        try await RuleFileManager<BudgetRuleFile>.addRule(original, journalFile: main, validator: PassingBackend())

        let updated = BudgetRule(
            account: "expenses:food",
            amount: Amount(commodity: "€", quantity: Decimal(string: "750.00")!)
        )
        try await RuleFileManager<BudgetRuleFile>.updateRule(
            key: "expenses:food", newRule: updated, journalFile: main, validator: PassingBackend()
        )

        let path = RuleFileManager<BudgetRuleFile>.filePath(for: main)
        let parsed = RuleFileManager<BudgetRuleFile>.parseRules(at: path)
        #expect(parsed.count == 1)
        #expect(parsed[0].amount.quantity == Decimal(string: "750.00")!)
    }

    @Test func updateRuleNotFoundThrows() async throws {
        let dir = try RFMHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try RFMHelpers.writeFile("include budget.journal\n", in: dir, name: "main.journal")
        try "".write(
            to: dir.appendingPathComponent("budget.journal"), atomically: true, encoding: .utf8
        )

        await #expect(throws: (any Error).self) {
            try await RuleFileManager<BudgetRuleFile>.updateRule(
                key: "expenses:nonexistent",
                newRule: RFMHelpers.makeBudgetRule(),
                journalFile: main,
                validator: PassingBackend()
            )
        }
    }

    // MARK: deleteRule

    @Test func deleteRuleRemovesRule() async throws {
        let dir = try RFMHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try RFMHelpers.writeFile("", in: dir, name: "main.journal")
        try await RuleFileManager<BudgetRuleFile>.addRule(
            RFMHelpers.makeBudgetRule(account: "expenses:food"), journalFile: main, validator: PassingBackend()
        )
        try await RuleFileManager<BudgetRuleFile>.addRule(
            RFMHelpers.makeBudgetRule(account: "expenses:rent", amount: "1200.00"), journalFile: main, validator: PassingBackend()
        )

        try await RuleFileManager<BudgetRuleFile>.deleteRule(
            key: "expenses:food", journalFile: main, validator: PassingBackend()
        )

        let path = RuleFileManager<BudgetRuleFile>.filePath(for: main)
        let remaining = RuleFileManager<BudgetRuleFile>.parseRules(at: path)
        #expect(remaining.count == 1)
        #expect(remaining[0].account == "expenses:rent")
    }

    @Test func deleteRuleNotFoundThrows() async throws {
        let dir = try RFMHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try RFMHelpers.writeFile("include budget.journal\n", in: dir, name: "main.journal")
        try "".write(
            to: dir.appendingPathComponent("budget.journal"), atomically: true, encoding: .utf8
        )

        await #expect(throws: (any Error).self) {
            try await RuleFileManager<BudgetRuleFile>.deleteRule(
                key: "expenses:nonexistent", journalFile: main, validator: PassingBackend()
            )
        }
    }
}
