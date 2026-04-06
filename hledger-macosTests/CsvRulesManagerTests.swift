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
