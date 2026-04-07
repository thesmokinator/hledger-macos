import Testing
import Foundation
@testable import hledger_for_Mac

// MARK: - Auto-Detection Tests

@Suite("CsvRulesManager.AutoDetection")
struct CsvAutoDetectionTests {

    @Test func detectsCommaSeparator() {
        let csv = "date,description,amount\n2024-01-01,Grocery,50.00\n2024-01-02,Rent,1200.00"
        #expect(CsvRulesManager.detectSeparator(csv) == .comma)
    }

    @Test func detectsSemicolonSeparator() {
        let csv = "date;description;amount\n2024-01-01;Grocery;50.00\n2024-01-02;Rent;1200.00"
        #expect(CsvRulesManager.detectSeparator(csv) == .semicolon)
    }

    @Test func detectsTabSeparator() {
        let csv = "date\tdescription\tamount\n2024-01-01\tGrocery\t50.00\n2024-01-02\tRent\t1200.00"
        #expect(CsvRulesManager.detectSeparator(csv) == .tab)
    }

    @Test func detectsPipeSeparator() {
        let csv = "date|description|amount\n2024-01-01|Grocery|50.00\n2024-01-02|Rent|1200.00"
        #expect(CsvRulesManager.detectSeparator(csv) == .pipe)
    }

    @Test func detectsHeaderRow() {
        let csv = "Date,Description,Amount\n2024-01-01,Grocery,50.00"
        let (hasHeader, headers) = CsvRulesManager.detectHeaderRow(csv, separator: .comma)
        #expect(hasHeader == true)
        #expect(headers == ["Date", "Description", "Amount"])
    }

    @Test func detectsNoHeaderRow() {
        let csv = "2024-01-01,Grocery,50.00\n2024-01-02,Rent,1200.00"
        let (hasHeader, headers) = CsvRulesManager.detectHeaderRow(csv, separator: .comma)
        #expect(hasHeader == false)
        #expect(headers.count == 3)
        #expect(headers[0] == "Col 1")
    }

    @Test func detectsISODateFormat() {
        let samples = ["2024-01-15", "2024-02-20", "2024-03-10"]
        #expect(CsvRulesManager.detectDateFormat(samples) == "%Y-%m-%d")
    }

    @Test func detectsEuropeanDateFormat() {
        let samples = ["15/01/2024", "20/02/2024", "10/03/2024"]
        #expect(CsvRulesManager.detectDateFormat(samples) == "%d/%m/%Y")
    }

    @Test func detectsDotDateFormat() {
        let samples = ["15.01.2024", "20.02.2024", "10.03.2024"]
        #expect(CsvRulesManager.detectDateFormat(samples) == "%d.%m.%Y")
    }

    @Test func autoMapsColumnsByHeaderName() {
        let headers = ["Date", "Description", "Amount"]
        let samples = [["2024-01-01", "Grocery Store", "50.00"]]
        let mappings = CsvRulesManager.autoMapColumns(headers: headers, sampleRows: samples)

        #expect(mappings[0].assignedField == .date)
        #expect(mappings[1].assignedField == .description)
        #expect(mappings[2].assignedField == .amount)
    }

    @Test func autoMapsColumnsWithCreditDebit() {
        let headers = ["Date", "Memo", "Credit", "Debit"]
        let samples = [["2024-01-01", "Payment", "100.00", ""]]
        let mappings = CsvRulesManager.autoMapColumns(headers: headers, sampleRows: samples)

        #expect(mappings[0].assignedField == .date)
        #expect(mappings[1].assignedField == .description)
        #expect(mappings[2].assignedField == .amountIn)
        #expect(mappings[3].assignedField == .amountOut)
    }

    @Test func autoMapsColumnsBySampleValues() {
        let headers = ["Col 1", "Col 2", "Col 3"]
        let samples = [
            ["2024-01-01", "Supermarket purchase for groceries", "50.00"],
            ["2024-01-02", "Monthly rent payment details", "1200.00"],
        ]
        let mappings = CsvRulesManager.autoMapColumns(headers: headers, sampleRows: samples)

        #expect(mappings[0].assignedField == .date)
        #expect(mappings[1].assignedField == .description)
        #expect(mappings[2].assignedField == .amount)
    }
}

// MARK: - CSV Parsing Tests

@Suite("CsvRulesManager.CsvParsing")
struct CsvParsingTests {

    @Test func splitSimpleLine() {
        let result = CsvRulesManager.splitCsvLine("a,b,c", separator: .comma)
        #expect(result == ["a", "b", "c"])
    }

    @Test func splitQuotedLine() {
        let result = CsvRulesManager.splitCsvLine("\"hello, world\",b,c", separator: .comma)
        #expect(result == ["hello, world", "b", "c"])
    }

    @Test func parseRawCsvWithSkip() {
        let csv = "Header1,Header2\nA,B\nC,D"
        let rows = CsvRulesManager.parseRawCsv(csv, separator: .comma, skipLines: 1)
        #expect(rows.count == 2)
        #expect(rows[0] == ["A", "B"])
    }
}

// MARK: - Rules File Format/Parse Tests

@Suite("CsvRulesManager.RulesFileIO")
struct RulesFileIOTests {

    @Test func formatAndParseRoundtrip() {
        var config = CsvRulesConfig()
        config.name = "Test Bank"
        config.separator = .semicolon
        config.skipLines = 1
        config.dateFormat = "%d/%m/%Y"
        config.defaultAccount = "assets:bank:checking"
        config.defaultCurrency = "EUR"
        config.columnMappings = [
            ColumnMapping(csvColumnIndex: 0, csvColumnHeader: "Date", assignedField: .date),
            ColumnMapping(csvColumnIndex: 1, csvColumnHeader: "Desc", assignedField: .description),
            ColumnMapping(csvColumnIndex: 2, csvColumnHeader: "Amount", assignedField: .amount),
        ]
        config.conditionalRules = [
            ConditionalRule(pattern: "grocery|supermarket", account: "expenses:groceries"),
        ]

        let formatted = CsvRulesManager.formatRulesFile(config)
        let parsed = CsvRulesManager.parseRulesContent(formatted)

        #expect(parsed.name == "Test Bank")
        #expect(parsed.separator == .semicolon)
        #expect(parsed.skipLines == 1)
        #expect(parsed.dateFormat == "%d/%m/%Y")
        #expect(parsed.defaultAccount == "assets:bank:checking")
        #expect(parsed.defaultCurrency == "EUR")
        #expect(parsed.columnMappings.count == 3)
        #expect(parsed.columnMappings[0].assignedField == .date)
        #expect(parsed.columnMappings[1].assignedField == .description)
        #expect(parsed.columnMappings[2].assignedField == .amount)
        #expect(parsed.conditionalRules.count == 1)
        #expect(parsed.conditionalRules[0].pattern == "grocery|supermarket")
        #expect(parsed.conditionalRules[0].account == "expenses:groceries")
    }

    @Test func parseRulesWithMultipleConditionals() {
        let content = """
        ; name: My Bank
        skip 1
        date-format %Y-%m-%d
        fields date, description, amount
        account1 assets:bank

        if groceries
          account2 expenses:food

        if rent|mortgage
          account2 expenses:housing
        """
        let config = CsvRulesManager.parseRulesContent(content)
        #expect(config.conditionalRules.count == 2)
        #expect(config.conditionalRules[0].account == "expenses:food")
        #expect(config.conditionalRules[1].pattern == "rent|mortgage")
        #expect(config.conditionalRules[1].account == "expenses:housing")
    }
}

// MARK: - Duplicate Detection Tests

@Suite("CsvRulesManager.DuplicateDetection")
struct DuplicateDetectionTests {

    @Test func detectsDuplicateByDateDescAmount() {
        let preview = [
            CsvPreviewTransaction(date: "2024-01-01", description: "Grocery", amount: "50"),
            CsvPreviewTransaction(date: "2024-01-02", description: "Rent", amount: "1200"),
        ]

        let existing = [
            Transaction(
                index: 0, date: "2024-01-01", description: "Grocery",
                postings: [Posting(account: "expenses:food", amounts: [Amount(commodity: "EUR", quantity: 50, style: .default)])],
                status: .cleared, code: "", comment: ""
            ),
        ]

        let result = CsvRulesManager.detectDuplicates(preview: preview, existing: existing)
        #expect(result[0].isDuplicate == true)
        #expect(result[0].isSelected == false)
        #expect(result[1].isDuplicate == false)
        #expect(result[1].isSelected == true)
    }
}

// MARK: - Rules Discovery Tests

@Suite("CsvRulesManager.Discovery")
struct RulesDiscoveryTests {

    @Test func companionRulesNotFoundForNonexistent() {
        let fakeCSV = URL(fileURLWithPath: "/tmp/nonexistent_csv_test_12345.csv")
        #expect(CsvRulesManager.findCompanionRules(for: fakeCSV) == nil)
    }
}

// MARK: - Fixture-Based Integration Tests

@Suite("CsvRulesManager.Fixtures")
struct CsvFixtureTests {

    private var fixturesDir: URL {
        let bundle = Bundle(for: BundleToken.self)
        return bundle.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("hledger-macosTests/Fixtures")
    }

    // Fallback: resolve from source directory
    private func fixtureURL(_ name: String) -> URL {
        // Try bundle-adjacent path first
        let bundlePath = fixturesDir.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: bundlePath.path) {
            return bundlePath
        }
        // Fallback to known project path
        let projectPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(name)")
        return projectPath
    }

    @Test func autoDetectSampleBankCsv() throws {
        let csvURL = fixtureURL("sample_bank.csv")
        let content = try String(contentsOf: csvURL, encoding: .utf8)

        let separator = CsvRulesManager.detectSeparator(content)
        #expect(separator == .comma)

        let (hasHeader, headers) = CsvRulesManager.detectHeaderRow(content, separator: separator)
        #expect(hasHeader == true)
        #expect(headers == ["Date", "Description", "Amount", "Balance"])

        let dataRows = CsvRulesManager.parseRawCsv(content, separator: separator, skipLines: 1)
            .filter { !$0.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty } }
        #expect(dataRows.count == 26)

        let mappings = CsvRulesManager.autoMapColumns(headers: headers, sampleRows: Array(dataRows.prefix(5)))
        #expect(mappings[0].assignedField == .date)
        #expect(mappings[1].assignedField == .description)
        #expect(mappings[2].assignedField == .amount)
        // Balance column should not be mapped to a known field
        #expect(mappings[3].assignedField == nil)
    }

    @Test func parseSampleBankRulesFile() throws {
        let rulesURL = fixtureURL("sample_bank.rules")
        let config = CsvRulesManager.parseRulesFile(url: rulesURL)
        #expect(config != nil)

        let rules = config!
        #expect(rules.name == "Sample Bank")
        #expect(rules.skipLines == 1)
        #expect(rules.dateFormat == "%d/%m/%Y")
        #expect(rules.defaultAccount == "assets:bank:checking")
        #expect(rules.defaultCurrency == "EUR")
        #expect(rules.conditionalRules.count >= 11)
        #expect(rules.conditionalRules[0].pattern == "whole foods|grocery store")
        #expect(rules.conditionalRules[0].account == "expenses:groceries")
    }

    @Test func detectDateFormatFromSampleBank() throws {
        let csvURL = fixtureURL("sample_bank.csv")
        let content = try String(contentsOf: csvURL, encoding: .utf8)
        let rows = CsvRulesManager.parseRawCsv(content, separator: .comma, skipLines: 1)
        let dateSamples = rows.prefix(5).map { $0[0] }

        let format = CsvRulesManager.detectDateFormat(dateSamples)
        #expect(format == "%d/%m/%Y")
    }
}

/// Helper to find the test bundle at runtime.
private class BundleToken {}
