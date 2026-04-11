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

// MARK: - PostingAmountParser Tests

@Suite("PostingAmountParser")
struct PostingAmountParserTests {

    // MARK: - Simple amounts

    @Test func parsePlainNumber() {
        let amount = PostingAmountParser.parse("50.00", defaultCommodity: "€")
        #expect(amount?.quantity == Decimal(string: "50.00"))
        #expect(amount?.commodity == "€")
        #expect(amount?.cost == nil)
    }

    @Test func parseNegativePlainNumber() {
        let amount = PostingAmountParser.parse("-123.45", defaultCommodity: "€")
        #expect(amount?.quantity == Decimal(string: "-123.45"))
        #expect(amount?.commodity == "€")
    }

    @Test func parseCurrencyPrefix() {
        let amount = PostingAmountParser.parse("€500.00")
        #expect(amount?.quantity == Decimal(string: "500.00"))
        #expect(amount?.commodity == "€")
        #expect(amount?.style.commoditySide == .left)
        #expect(amount?.style.commoditySpaced == false)
    }

    @Test func parseCurrencySuffix() {
        let amount = PostingAmountParser.parse("500.00 EUR")
        #expect(amount?.quantity == Decimal(string: "500.00"))
        #expect(amount?.commodity == "EUR")
        #expect(amount?.style.commoditySide == .right)
        #expect(amount?.style.commoditySpaced == true)
    }

    @Test func parseEuropeanFormatSimple() {
        let amount = PostingAmountParser.parse("€50,00")
        #expect(amount?.quantity == Decimal(string: "50"))
        #expect(amount?.commodity == "€")
    }

    @Test func parseEuropeanFormatThousands() {
        let amount = PostingAmountParser.parse("€1.000,50")
        #expect(amount?.quantity == Decimal(string: "1000.5"))
        #expect(amount?.commodity == "€")
    }

    @Test func parseUSFormat() {
        let amount = PostingAmountParser.parse("$1,000.50")
        #expect(amount?.quantity == Decimal(string: "1000.5"))
        #expect(amount?.commodity == "$")
    }

    @Test func parseNamedCommodityNoCost() {
        let amount = PostingAmountParser.parse("10 AAPL")
        #expect(amount?.quantity == 10)
        #expect(amount?.commodity == "AAPL")
        #expect(amount?.cost == nil)
    }

    @Test func parseNegativeNamedCommodity() {
        let amount = PostingAmountParser.parse("-5 XDWD")
        #expect(amount?.quantity == -5)
        #expect(amount?.commodity == "XDWD")
        #expect(amount?.cost == nil)
    }

    // MARK: - Cost annotation: @@ (total cost)

    /// Regression test for the original bug: European decimal in @@ cost.
    /// Input "-1 SWDA @@ 112,93" was previously rejected by hledger because
    /// the comma wasn't being normalized to a dot before writing the journal.
    @Test func parseTotalCostEuropeanDecimal() {
        let amount = PostingAmountParser.parse("-1 SWDA @@ 112,93", defaultCommodity: "€")
        #expect(amount?.quantity == -1)
        #expect(amount?.commodity == "SWDA")
        #expect(amount?.cost?.quantity == Decimal(string: "112.93"))
        #expect(amount?.cost?.commodity == "€")
    }

    @Test func parseTotalCostDotDecimal() {
        let amount = PostingAmountParser.parse("-5 XDWD @@ €742.55")
        #expect(amount?.quantity == -5)
        #expect(amount?.commodity == "XDWD")
        #expect(amount?.cost?.quantity == Decimal(string: "742.55"))
        #expect(amount?.cost?.commodity == "€")
    }

    @Test func parseTotalCostWithCurrencySuffix() {
        let amount = PostingAmountParser.parse("10 AAPL @@ 1500.00 USD")
        #expect(amount?.quantity == 10)
        #expect(amount?.commodity == "AAPL")
        #expect(amount?.cost?.quantity == Decimal(string: "1500.00"))
        #expect(amount?.cost?.commodity == "USD")
    }

    @Test func parseTotalCostEuropeanThousands() {
        let amount = PostingAmountParser.parse("-5 XDWD @@ €1.000,00")
        #expect(amount?.quantity == -5)
        #expect(amount?.cost?.quantity == Decimal(string: "1000"))
    }

    @Test func parseTotalCostNoExplicitCommodity() {
        // Cost "112,93" with no commodity → should use defaultCommodity
        let amount = PostingAmountParser.parse("-1 SWDA @@ 112,93", defaultCommodity: "€")
        #expect(amount?.cost?.commodity == "€")
    }

    @Test func parseTotalCostAlwaysPositive() {
        // hledger requires the @@ cost to be positive, even for sells
        let amount = PostingAmountParser.parse("-1 SWDA @@ 112.93", defaultCommodity: "€")
        #expect(amount?.cost?.quantity == Decimal(string: "112.93"))
    }

    // MARK: - Cost annotation: @ (unit cost)

    @Test func parseUnitCost() {
        // @ is unit cost: total = qty × unit
        // -5 XDWD @ €148.00 → total cost = 5 × 148 = 740
        let amount = PostingAmountParser.parse("-5 XDWD @ €148.00")
        #expect(amount?.quantity == -5)
        #expect(amount?.cost?.quantity == Decimal(string: "740"))
    }

    @Test func parseUnitCostEuropeanDecimal() {
        // -1 SWDA @ 112,93 → total cost = 1 × 112.93 = 112.93
        let amount = PostingAmountParser.parse("-1 SWDA @ 112,93", defaultCommodity: "€")
        #expect(amount?.cost?.quantity == Decimal(string: "112.93"))
    }

    // MARK: - Edge cases

    @Test func parseEmptyString() {
        #expect(PostingAmountParser.parse("") == nil)
        #expect(PostingAmountParser.parse("   ") == nil)
    }

    @Test func parseZero() {
        // "0" with no commodity → nil (consistent with previous behavior)
        #expect(PostingAmountParser.parse("0") == nil)
    }

    @Test func parseGarbageString() {
        #expect(PostingAmountParser.parse("not a number") == nil)
    }

    @Test func parseCostWithoutCommodity() {
        // "@@ 100" has no quantity/commodity prefix → invalid
        #expect(PostingAmountParser.parseCostAnnotated("@@ 100") == nil)
    }

    @Test func parseCostWithoutCostValue() {
        // Missing cost amount after @@ is caught by the regex (requires .+)
        #expect(PostingAmountParser.parseCostAnnotated("-1 SWDA @@") == nil)
    }

    @Test func parseCostWithInvalidCostAmount() {
        // Cost portion cannot be parsed as a number
        #expect(PostingAmountParser.parseCostAnnotated("-1 SWDA @@ garbage") == nil)
    }

    // MARK: - Roundtrip: parse → format → hledger-compatible output

    /// Critical test: European input must produce hledger-compatible output.
    /// User types `-1 SWDA @@ 112,93` (Italian) → journal must contain `112.93`.
    @Test func roundtripEuropeanInputProducesDotOutput() {
        let amount = PostingAmountParser.parse("-1 SWDA @@ 112,93", defaultCommodity: "€")!
        let formatted = amount.formatted()
        // Must contain the dot-normalized cost, no comma
        #expect(formatted.contains("112.93"))
        #expect(!formatted.contains("112,93"))
        #expect(formatted.contains("@@"))
    }

    @Test func roundtripSimpleEuropeanInputProducesDotOutput() {
        let amount = PostingAmountParser.parse("€50,00")!
        let formatted = amount.formatted()
        #expect(formatted.contains("50.00"))
        #expect(!formatted.contains("50,00"))
    }

    @Test func roundtripCostAnnotatedFormatIncludesCostMarker() {
        let amount = PostingAmountParser.parse("-5 XDWD @@ €742.55")!
        let formatted = amount.formatted()
        #expect(formatted.contains("XDWD"))
        #expect(formatted.contains("@@"))
        #expect(formatted.contains("742.55"))
    }

    /// When editing an existing transaction, the prefilled amount string comes from
    /// `Amount.formatted()`. Re-parsing that string must yield an equivalent Amount,
    /// so the user can edit and save without losing information.
    @Test func roundtripCostAnnotatedFullCycle() {
        let parsed = PostingAmountParser.parse("-5 XDWD @@ €742.55")!
        let formatted = parsed.formatted()
        let reparsed = PostingAmountParser.parse(formatted)!

        #expect(reparsed.quantity == parsed.quantity)
        #expect(reparsed.commodity == parsed.commodity)
        #expect(reparsed.cost?.quantity == parsed.cost?.quantity)
        #expect(reparsed.cost?.commodity == parsed.cost?.commodity)
    }

    @Test func roundtripEuropeanInputFullCycle() {
        // User types European format → formatted in hledger format → reparsed
        let parsed = PostingAmountParser.parse("-1 SWDA @@ 112,93", defaultCommodity: "€")!
        let formatted = parsed.formatted()
        let reparsed = PostingAmountParser.parse(formatted)!

        #expect(reparsed.quantity == -1)
        #expect(reparsed.commodity == "SWDA")
        #expect(reparsed.cost?.quantity == Decimal(string: "112.93"))
        #expect(reparsed.cost?.commodity == "€")
    }

    // MARK: - decimalPlaces helper

    @Test func decimalPlacesNoSeparator() {
        #expect(PostingAmountParser.decimalPlaces(in: "50") == 0)
        #expect(PostingAmountParser.decimalPlaces(in: "1000") == 0)
    }

    @Test func decimalPlacesDotDecimal() {
        #expect(PostingAmountParser.decimalPlaces(in: "50.00") == 2)
        #expect(PostingAmountParser.decimalPlaces(in: "50.5") == 1)
        #expect(PostingAmountParser.decimalPlaces(in: "50.123") == 3)
    }

    @Test func decimalPlacesCommaDecimal() {
        #expect(PostingAmountParser.decimalPlaces(in: "50,00") == 2)
        #expect(PostingAmountParser.decimalPlaces(in: "112,93") == 2)
        #expect(PostingAmountParser.decimalPlaces(in: "50,5") == 1)
    }

    @Test func decimalPlacesEuropeanThousands() {
        // "1.000,50" → European: dot is thousands, comma is decimal → 2 places
        #expect(PostingAmountParser.decimalPlaces(in: "1.000,50") == 2)
    }

    @Test func decimalPlacesUSThousands() {
        // "1,000.50" → US: comma is thousands, dot is decimal → 2 places
        #expect(PostingAmountParser.decimalPlaces(in: "1,000.50") == 2)
    }

    @Test func decimalPlacesCommaAsThousands() {
        // "1,000" → 3 digits after comma → thousands separator → 0 places
        #expect(PostingAmountParser.decimalPlaces(in: "1,000") == 0)
    }

    @Test func decimalPlacesWithCurrencyPrefix() {
        #expect(PostingAmountParser.decimalPlaces(in: "€50.00") == 2)
        #expect(PostingAmountParser.decimalPlaces(in: "-€50,00") == 2)
    }

    @Test func decimalPlacesNegative() {
        #expect(PostingAmountParser.decimalPlaces(in: "-50.00") == 2)
        #expect(PostingAmountParser.decimalPlaces(in: "-112,93") == 2)
    }

    // MARK: - Issue #95 gaps: literal #83 regression and edge cases

    /// Literal regression test for the exact string in issue #83:
    /// `€` symbol prefix + comma decimal, no thousands separator.
    /// The pre-existing `parseTotalCostEuropeanDecimal` covers a similar case
    /// without the `€` symbol; this asserts the literal failing input.
    @Test func parseTotalCostLiteralIssue83() {
        let amount = PostingAmountParser.parse("-5 XDWD @@ €742,55")
        #expect(amount?.quantity == -5)
        #expect(amount?.commodity == "XDWD")
        #expect(amount?.cost?.quantity == Decimal(string: "742.55"))
        #expect(amount?.cost?.commodity == "€")
        // Formatted output must use `.` (hledger-compatible), never `,`
        let formatted = amount!.formatted()
        #expect(formatted.contains("742.55"))
        #expect(!formatted.contains("742,55"))
    }

    @Test func parseTotalCostExtraWhitespaceAroundOperator() {
        // Multiple spaces around @@ are tolerated by `\s+` in the regex
        let amount = PostingAmountParser.parse("-5 XDWD   @@   €742,55")
        #expect(amount?.quantity == -5)
        #expect(amount?.cost?.quantity == Decimal(string: "742.55"))
    }

    @Test func parseTotalCostZeroValue() {
        // Zero cost is valid: e.g. a free promotional share
        let amount = PostingAmountParser.parse("-5 XDWD @@ €0")
        #expect(amount?.cost?.quantity == 0)
        #expect(amount?.cost?.commodity == "€")
    }

    @Test func parseTotalCostZeroValueEuropeanDecimal() {
        let amount = PostingAmountParser.parse("-5 XDWD @@ €0,00")
        #expect(amount?.cost?.quantity == 0)
    }

    @Test func parseTotalCostNegativeInputNormalizedToPositive() {
        // hledger requires @@ cost to be positive even when the user types a
        // negative number. The parser must apply `abs()` so the formatted
        // output never contains a negative cost.
        let amount = PostingAmountParser.parse("-5 XDWD @@ -€100,00")
        #expect(amount?.quantity == -5)
        #expect(amount?.cost?.quantity == Decimal(string: "100"))
        let formatted = amount!.formatted()
        #expect(!formatted.contains("@@ -"))
        #expect(!formatted.contains("@@-"))
    }

    @Test func parseSimpleDirectCallReturnsNonNil() {
        // The existing suite only tests via top-level `parse()`. Cover the
        // public `parseSimple` entry point directly.
        let amount = PostingAmountParser.parseSimple("€50,00")
        #expect(amount?.quantity == 50)
        #expect(amount?.commodity == "€")
        #expect(amount?.cost == nil)
    }

    @Test func parseCostAnnotatedReturnsNilForPlainSimpleAmount() {
        // The cost regex must not false-match a plain amount with no `@`.
        // Calling `parseCostAnnotated` directly on `€50,00` should return nil,
        // forcing callers (like `parse`) to fall back to `parseSimple`.
        #expect(PostingAmountParser.parseCostAnnotated("€50,00") == nil)
        #expect(PostingAmountParser.parseCostAnnotated("-1 SWDA") == nil)
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

    // MARK: - Issue #99: alignment and round-trip safety
    //
    // These tests verify the correctness of column alignment and field
    // preservation. Bugs here corrupt user data on transaction edit, so
    // we assert exact strings rather than just substrings.

    @Test func unmarkedStatusOmitsMarker() {
        let txn = Transaction(index: 0, date: "2026-01-01", description: "Test", status: .unmarked)
        let result = TransactionFormatter.format(txn)
        // Header must NOT contain a status marker
        let header = result.split(separator: "\n").first.map(String.init) ?? ""
        #expect(header == "2026-01-01 Test")
    }

    @Test func basicAlignmentTwoPostings() {
        let txn = Transaction(
            index: 0, date: "2026-01-01", description: "Lunch",
            postings: [
                Posting(account: "expenses:food", amounts: [
                    Amount(commodity: "€", quantity: Decimal(string: "12.50")!)
                ]),
                Posting(account: "assets:bank")
            ],
            status: .unmarked
        )
        let result = TransactionFormatter.format(txn)
        let lines = result.split(separator: "\n").map(String.init)
        #expect(lines.count == 3)
        // Postings start with 4-space indent
        #expect(lines[1].hasPrefix("    expenses:food"))
        #expect(lines[2].hasPrefix("    assets:bank"))
    }

    @Test func varyingAccountLengthsProduceAlignedAmountColumn() {
        // Two postings with different-length accounts must produce amounts
        // aligned to the same column. Default minimum account width is 40.
        let txn = Transaction(
            index: 0, date: "2026-01-01", description: "Test",
            postings: [
                Posting(account: "expenses:short", amounts: [
                    Amount(commodity: "€", quantity: Decimal(string: "10.00")!)
                ]),
                Posting(account: "expenses:much:longer:account:name", amounts: [
                    Amount(commodity: "€", quantity: Decimal(string: "20.00")!)
                ]),
            ],
            status: .unmarked
        )
        let result = TransactionFormatter.format(txn)
        let lines = result.split(separator: "\n").map(String.init)
        // Find the position of the amount on each posting line — must be equal
        let euroPos1 = lines[1].range(of: "€")?.lowerBound
        let euroPos2 = lines[2].range(of: "€")?.lowerBound
        #expect(euroPos1 != nil && euroPos2 != nil)
        let dist1 = lines[1].distance(from: lines[1].startIndex, to: euroPos1!)
        let dist2 = lines[2].distance(from: lines[2].startIndex, to: euroPos2!)
        #expect(dist1 == dist2)
    }

    @Test func varyingAmountLengthsRightAligned() {
        let txn = Transaction(
            index: 0, date: "2026-01-01", description: "Test",
            postings: [
                Posting(account: "expenses:a", amounts: [
                    Amount(commodity: "€", quantity: Decimal(string: "5.00")!)
                ]),
                Posting(account: "expenses:b", amounts: [
                    Amount(commodity: "€", quantity: Decimal(string: "12345.67")!)
                ]),
            ],
            status: .unmarked
        )
        let result = TransactionFormatter.format(txn)
        let lines = result.split(separator: "\n").map(String.init)
        // Both amount lines must end at the same column (right-aligned)
        #expect(lines[1].count == lines[2].count)
        // The shorter amount line should have leading spaces before €
        let euroIdx = lines[1].range(of: "€")!.lowerBound
        let beforeEuro = lines[1][..<euroIdx]
        // After the account "expenses:a" + 2-space gap there must be padding
        #expect(beforeEuro.contains("  "))
    }

    @Test func postingWithoutAmountIsBareAccount() {
        let txn = Transaction(
            index: 0, date: "2026-01-01", description: "Test",
            postings: [
                Posting(account: "assets:bank", amounts: [
                    Amount(commodity: "€", quantity: Decimal(string: "100.00")!)
                ]),
                Posting(account: "expenses:food")  // no amount → balanced posting
            ],
            status: .unmarked
        )
        let result = TransactionFormatter.format(txn)
        let lines = result.split(separator: "\n").map(String.init)
        // The bare-account posting line must not contain digits or commodities
        #expect(lines[2] == "    expenses:food")
    }

    @Test func balanceAssertionPreserved() {
        let txn = Transaction(
            index: 0, date: "2026-01-01", description: "Reconcile",
            postings: [
                Posting(
                    account: "assets:bank",
                    amounts: [Amount(commodity: "€", quantity: Decimal(string: "50.00")!)],
                    balanceAssertion: "= €1000.00"
                ),
                Posting(account: "income:salary")
            ],
            status: .unmarked
        )
        let result = TransactionFormatter.format(txn)
        #expect(result.contains("= €1000.00"))
    }

    @Test func postingCommentPreserved() {
        let txn = Transaction(
            index: 0, date: "2026-01-01", description: "Test",
            postings: [
                Posting(
                    account: "expenses:food",
                    amounts: [Amount(commodity: "€", quantity: Decimal(string: "10.00")!)],
                    comment: "lunch detail"
                ),
                Posting(account: "assets:bank")
            ],
            status: .unmarked
        )
        let result = TransactionFormatter.format(txn)
        #expect(result.contains("; lunch detail"))
    }

    @Test func costAnnotationInFormattedOutput() {
        let cost = CostAmount(commodity: "€", quantity: Decimal(string: "742.55")!)
        let txn = Transaction(
            index: 0, date: "2026-01-01", description: "Buy ETF",
            postings: [
                Posting(account: "assets:investments", amounts: [
                    Amount(commodity: "XDWD", quantity: -5, cost: cost)
                ]),
                Posting(account: "assets:cash")
            ],
            status: .unmarked
        )
        let result = TransactionFormatter.format(txn)
        // Cost is always emitted as @@ (total cost) by Amount.formatted()
        #expect(result.contains("@@"))
        #expect(result.contains("XDWD"))
        // Cost commodity must be present after @@
        #expect(result.contains("742.55"))
    }

    @Test func veryLongAccountNamePreserved() {
        // Account longer than the 40-char minimum width: width must expand
        // to fit the longest account, the 2-space gap before the amount
        // must still be there, and the account name must not be truncated.
        let longAccount = "expenses:taxes:state:california:property:residential:primary"
        let txn = Transaction(
            index: 0, date: "2026-01-01", description: "Test",
            postings: [
                Posting(account: longAccount, amounts: [
                    Amount(commodity: "€", quantity: Decimal(string: "100.00")!)
                ]),
                Posting(account: "assets:bank")
            ],
            status: .unmarked
        )
        let result = TransactionFormatter.format(txn)
        #expect(result.contains(longAccount))
        // The amount must still appear and not be cut off
        #expect(result.contains("€100.00"))
    }

    @Test func veryLongAmountPreserved() {
        // Amount string longer than the 12-char minimum width
        let txn = Transaction(
            index: 0, date: "2026-01-01", description: "Test",
            postings: [
                Posting(account: "assets:bank", amounts: [
                    Amount(commodity: "€", quantity: Decimal(string: "1234567890.12")!)
                ]),
                Posting(account: "income:windfall")
            ],
            status: .unmarked
        )
        let result = TransactionFormatter.format(txn)
        #expect(result.contains("€1234567890.12"))
    }

    @Test func headerWithStatusCodeAndComment() {
        let txn = Transaction(
            index: 0,
            date: "2026-01-01",
            description: "Test",
            status: .cleared,
            code: "INV-42",
            comment: "header note"
        )
        let result = TransactionFormatter.format(txn)
        let header = result.split(separator: "\n").first.map(String.init) ?? ""
        // Order is: date, status marker, (code), description, then "  ; comment"
        #expect(header.hasPrefix("2026-01-01 * (INV-42) Test"))
        #expect(header.contains("; header note"))
    }

    @Test func multiplePostingsAllAlignedSameColumn() {
        // 4 postings with mixed account lengths must all align to the same column
        let txn = Transaction(
            index: 0, date: "2026-01-01", description: "Split",
            postings: [
                Posting(account: "expenses:a", amounts: [
                    Amount(commodity: "€", quantity: Decimal(string: "10.00")!)
                ]),
                Posting(account: "expenses:bb", amounts: [
                    Amount(commodity: "€", quantity: Decimal(string: "20.00")!)
                ]),
                Posting(account: "expenses:ccc", amounts: [
                    Amount(commodity: "€", quantity: Decimal(string: "30.00")!)
                ]),
                Posting(account: "assets:bank")
            ],
            status: .unmarked
        )
        let result = TransactionFormatter.format(txn)
        let lines = result.split(separator: "\n").map(String.init)
        // First three posting lines have amounts → € must be at the same column
        let positions = lines[1...3].map { line -> Int in
            let idx = line.range(of: "€")!.lowerBound
            return line.distance(from: line.startIndex, to: idx)
        }
        #expect(positions[0] == positions[1])
        #expect(positions[1] == positions[2])
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
    func parseCsvImport(csvFile: URL, rulesFile: URL) async throws -> [Transaction] { [] }
    func validateCsvRules(csvFile: URL, rulesFile: URL) async throws {}
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
