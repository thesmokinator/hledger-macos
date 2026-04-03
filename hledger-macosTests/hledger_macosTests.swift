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
