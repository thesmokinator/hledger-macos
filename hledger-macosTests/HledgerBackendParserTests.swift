import Testing
import Foundation
@testable import hledger_for_Mac

// MARK: - Helpers

/// Build a minimal hledger-style amount dict for parser tests.
fileprivate func amountDict(
    commodity: String = "€",
    mantissa: Int = 5000,
    places: Int = 2,
    side: String = "L",
    spaced: Bool = false,
    decimalMark: String = ".",
    digitGroupSeparator: String? = nil,
    digitGroupSizes: [Int] = [],
    precision: Int = 2,
    cost: [String: Any]? = nil
) -> [String: Any] {
    var style: [String: Any] = [
        "ascommodityside": side,
        "ascommodityspaced": spaced,
        "asdecimalmark": decimalMark,
        "asprecision": precision,
        "asrounding": "NoRounding"
    ]
    if let sep = digitGroupSeparator {
        style["asdigitgroups"] = [sep, digitGroupSizes]
    }

    var dict: [String: Any] = [
        "acommodity": commodity,
        "aquantity": [
            "decimalMantissa": mantissa,
            "decimalPlaces": places,
            "floatingPoint": Double(mantissa) / pow(10.0, Double(places))
        ],
        "astyle": style,
        "acostbasis": NSNull()
    ]
    dict["acost"] = cost ?? NSNull()
    return dict
}

fileprivate func postingDict(
    account: String,
    amounts: [[String: Any]] = [],
    status: String = "Unmarked",
    comment: String = "",
    balanceAssertion: [String: Any]? = nil
) -> [String: Any] {
    [
        "paccount": account,
        "pamount": amounts,
        "pstatus": status,
        "pcomment": comment,
        "pbalanceassertion": balanceAssertion as Any? ?? NSNull(),
        "ptags": []
    ]
}

// MARK: - parseTransaction

@Suite("HledgerBackend.parseTransaction")
struct ParseTransactionTests {

    @Test func parsesUnmarkedTransaction() {
        let dict: [String: Any] = [
            "tindex": 1,
            "tdate": "2026-04-15",
            "tdescription": "Test",
            "tstatus": "Unmarked",
            "tcode": "",
            "tcomment": "",
            "tpostings": [],
            "ttags": []
        ]
        let txn = HledgerBackend.parseTransaction(dict)
        #expect(txn.index == 1)
        #expect(txn.date == "2026-04-15")
        #expect(txn.description == "Test")
        #expect(txn.status == .unmarked)
    }

    @Test func parsesClearedTransaction() {
        let dict: [String: Any] = [
            "tdate": "2026-04-15", "tdescription": "T",
            "tstatus": "Cleared", "tpostings": [], "ttags": []
        ]
        #expect(HledgerBackend.parseTransaction(dict).status == .cleared)
    }

    @Test func parsesPendingTransaction() {
        let dict: [String: Any] = [
            "tdate": "2026-04-15", "tdescription": "T",
            "tstatus": "Pending", "tpostings": [], "ttags": []
        ]
        #expect(HledgerBackend.parseTransaction(dict).status == .pending)
    }

    @Test func parsesTransactionWithCode() {
        let dict: [String: Any] = [
            "tdate": "2026-04-15", "tdescription": "T",
            "tcode": "INV-001", "tpostings": [], "ttags": []
        ]
        #expect(HledgerBackend.parseTransaction(dict).code == "INV-001")
    }

    @Test func parsesTransactionWithComment() {
        let dict: [String: Any] = [
            "tdate": "2026-04-15", "tdescription": "T",
            "tcomment": "  inline note\n", "tpostings": [], "ttags": []
        ]
        let txn = HledgerBackend.parseTransaction(dict)
        // Comment is trimmed
        #expect(txn.comment == "inline note")
    }

    @Test func parsesTransactionWithSourcePosition() {
        let dict: [String: Any] = [
            "tdate": "2026-04-15", "tdescription": "T",
            "tpostings": [], "ttags": [],
            "tsourcepos": [
                ["sourceName": "/tmp/main.journal", "sourceLine": 10, "sourceColumn": 1],
                ["sourceName": "/tmp/main.journal", "sourceLine": 13, "sourceColumn": 1]
            ]
        ]
        let txn = HledgerBackend.parseTransaction(dict)
        #expect(txn.sourcePosStart?.sourceName == "/tmp/main.journal")
        #expect(txn.sourcePosStart?.sourceLine == 10)
        #expect(txn.sourcePosEnd?.sourceLine == 13)
    }

    @Test func parsesTransactionWithoutSourcePositionWhenMissing() {
        let dict: [String: Any] = [
            "tdate": "2026-04-15", "tdescription": "T",
            "tpostings": [], "ttags": []
        ]
        let txn = HledgerBackend.parseTransaction(dict)
        #expect(txn.sourcePosStart == nil)
        #expect(txn.sourcePosEnd == nil)
    }

    @Test func parsesTransactionWithTags() {
        // hledger ttags format: [[name, value], [name, value]]
        // Empty value → just the name; non-empty → "name:value"
        let dict: [String: Any] = [
            "tdate": "2026-04-15", "tdescription": "T",
            "tpostings": [],
            "ttags": [
                ["category", ""],
                ["project", "alpha"]
            ]
        ]
        let txn = HledgerBackend.parseTransaction(dict)
        #expect(txn.tags.contains("category"))
        #expect(txn.tags.contains("project:alpha"))
    }

    @Test func parsesTransactionWithDate2() {
        let dict: [String: Any] = [
            "tdate": "2026-04-15",
            "tdate2": "2026-04-20",
            "tdescription": "T",
            "tpostings": [], "ttags": []
        ]
        #expect(HledgerBackend.parseTransaction(dict).date2 == "2026-04-20")
    }

    @Test func missingFieldsUseDefaults() {
        // Empty dict — every field should fall back to its default
        let txn = HledgerBackend.parseTransaction([:])
        #expect(txn.index == 0)
        #expect(txn.date == "")
        #expect(txn.description == "")
        #expect(txn.status == .unmarked)
        #expect(txn.code == "")
        #expect(txn.postings.isEmpty)
        #expect(txn.tags.isEmpty)
    }

    @Test func unknownStatusFallsBackToUnmarked() {
        let dict: [String: Any] = [
            "tdate": "2026-04-15", "tdescription": "T",
            "tstatus": "GarbageStatus", "tpostings": [], "ttags": []
        ]
        #expect(HledgerBackend.parseTransaction(dict).status == .unmarked)
    }
}

// MARK: - parsePosting

@Suite("HledgerBackend.parsePosting")
struct ParsePostingTests {

    @Test func parsesPostingWithAccount() {
        let dict = postingDict(account: "assets:bank")
        #expect(HledgerBackend.parsePosting(dict).account == "assets:bank")
    }

    @Test func parsesPostingWithComment() {
        let dict = postingDict(account: "expenses:food", comment: "  lunch\n")
        // Comment is trimmed
        #expect(HledgerBackend.parsePosting(dict).comment == "lunch")
    }

    @Test func parsesPostingWithBalanceAssertionInexact() {
        let assertion: [String: Any] = [
            "baamount": [amountDict(mantissa: 100000, places: 2)],
            "baexact": false
        ]
        let dict = postingDict(account: "assets:bank", balanceAssertion: assertion)
        let posting = HledgerBackend.parsePosting(dict)
        // Inexact assertion uses single =
        #expect(posting.balanceAssertion.hasPrefix("="))
        #expect(!posting.balanceAssertion.hasPrefix("=="))
    }

    @Test func parsesPostingWithBalanceAssertionExact() {
        let assertion: [String: Any] = [
            "baamount": [amountDict(mantissa: 100000, places: 2)],
            "baexact": true
        ]
        let dict = postingDict(account: "assets:bank", balanceAssertion: assertion)
        // Exact assertion uses ==
        #expect(HledgerBackend.parsePosting(dict).balanceAssertion.hasPrefix("=="))
    }

    @Test func postingWithoutBalanceAssertionHasEmptyString() {
        let dict = postingDict(account: "assets:bank")
        #expect(HledgerBackend.parsePosting(dict).balanceAssertion == "")
    }

    @Test func parsesPostingClearedStatus() {
        let dict = postingDict(account: "a", status: "Cleared")
        #expect(HledgerBackend.parsePosting(dict).status == .cleared)
    }
}

// MARK: - parseAmount

@Suite("HledgerBackend.parseAmount")
struct ParseAmountTests {

    @Test func parsesPlainAmount() {
        let dict = amountDict(commodity: "€", mantissa: 12345, places: 2)
        let amount = HledgerBackend.parseAmount(dict)
        #expect(amount.commodity == "€")
        #expect(amount.quantity == Decimal(string: "123.45"))
    }

    @Test func parsesNegativeAmount() {
        let dict = amountDict(mantissa: -50000, places: 2)
        let amount = HledgerBackend.parseAmount(dict)
        #expect(amount.quantity == Decimal(string: "-500"))
    }

    @Test func parsesEuropeanStyle() {
        let dict = amountDict(
            commodity: "€",
            decimalMark: ",",
            digitGroupSeparator: ".",
            digitGroupSizes: [3]
        )
        let amount = HledgerBackend.parseAmount(dict)
        #expect(amount.style.decimalMark == ",")
        #expect(amount.style.digitGroupSeparator == ".")
        #expect(amount.style.digitGroupSizes == [3])
    }

    @Test func parsesIndianStyle() {
        // Indian style: commas separate at 3, then 2, 2, 2 (e.g. 1,00,00,000)
        let dict = amountDict(
            commodity: "₹",
            decimalMark: ".",
            digitGroupSeparator: ",",
            digitGroupSizes: [3, 2]
        )
        let amount = HledgerBackend.parseAmount(dict)
        #expect(amount.style.digitGroupSizes == [3, 2])
    }

    @Test func parsesRightSideCommodity() {
        let dict = amountDict(commodity: "EUR", side: "R", spaced: true)
        let amount = HledgerBackend.parseAmount(dict)
        #expect(amount.style.commoditySide == .right)
        #expect(amount.style.commoditySpaced == true)
    }

    @Test func parsesAmountWithUnitCost() {
        // -5 XDWD @ €148.00 → unit cost. Total cost = abs(148 * -5) = 740
        let costDict: [String: Any] = [
            "tag": "UnitCost",
            "contents": amountDict(commodity: "€", mantissa: 14800, places: 2)
        ]
        let dict = amountDict(
            commodity: "XDWD",
            mantissa: -500,
            places: 2,  // -5.00
            cost: costDict
        )
        let amount = HledgerBackend.parseAmount(dict)
        #expect(amount.commodity == "XDWD")
        #expect(amount.quantity == Decimal(string: "-5"))
        #expect(amount.cost?.commodity == "€")
        // Unit cost: |148 * -5| = 740
        #expect(amount.cost?.quantity == Decimal(string: "740"))
    }

    @Test func parsesAmountWithTotalCost() {
        // -5 XDWD @@ €742.55 → total cost. Stored as-is (abs).
        let costDict: [String: Any] = [
            "tag": "TotalCost",
            "contents": amountDict(commodity: "€", mantissa: 74255, places: 2)
        ]
        let dict = amountDict(
            commodity: "XDWD",
            mantissa: -500,
            places: 2,
            cost: costDict
        )
        let amount = HledgerBackend.parseAmount(dict)
        #expect(amount.cost?.quantity == Decimal(string: "742.55"))
    }

    @Test func parsesAmountWithoutCost() {
        let dict = amountDict()
        #expect(HledgerBackend.parseAmount(dict).cost == nil)
    }

    @Test func missingFieldsProduceZeroAmount() {
        // Empty dict → zero, empty commodity, default style
        let amount = HledgerBackend.parseAmount([:])
        #expect(amount.commodity == "")
        #expect(amount.quantity == 0)
    }
}

// MARK: - expandSearchQuery

@Suite("HledgerBackend.expandSearchQuery")
struct ExpandSearchQueryTests {

    @Test func expandsDescriptionAlias() {
        #expect(HledgerBackend.expandSearchQuery("d:lunch") == "desc:lunch")
    }

    @Test func expandsAccountAlias() {
        #expect(HledgerBackend.expandSearchQuery("ac:bank") == "acct:bank")
    }

    @Test func expandsAmountAlias() {
        #expect(HledgerBackend.expandSearchQuery("am:>100") == "amt:>100")
    }

    @Test func expandsTagAlias() {
        #expect(HledgerBackend.expandSearchQuery("t:project") == "tag:project")
    }

    @Test func expandsStatusAlias() {
        #expect(HledgerBackend.expandSearchQuery("st:cleared") == "status:cleared")
    }

    @Test func multipleTokensExpandedIndependently() {
        let result = HledgerBackend.expandSearchQuery("d:lunch ac:food")
        #expect(result == "desc:lunch acct:food")
    }

    @Test func fullPrefixesNotDoubleExpanded() {
        // `desc:foo` already has the full prefix → must not become `desdesc:foo`
        #expect(HledgerBackend.expandSearchQuery("desc:foo") == "desc:foo")
        #expect(HledgerBackend.expandSearchQuery("acct:bank") == "acct:bank")
    }

    @Test func aliasInsideTokenNotMatched() {
        // `acct:t:foo` must NOT have its inner `t:` expanded — alias only
        // matches at the START of a space-separated token.
        let result = HledgerBackend.expandSearchQuery("acct:t:foo")
        #expect(result == "acct:t:foo")
    }

    @Test func emptyQueryReturnsEmpty() {
        #expect(HledgerBackend.expandSearchQuery("") == "")
    }

    @Test func queryWithoutAliasPassesThrough() {
        #expect(HledgerBackend.expandSearchQuery("plain text") == "plain text")
    }
}

// MARK: - parseCSVAccountBalances additional cases

@Suite("HledgerBackend.parseCSVAccountBalances additional")
struct ParseCSVAccountBalancesAdditionalTests {

    @Test func parsesMultipleAccounts() {
        let csv = """
        "account","balance"
        "assets:bank","€5000.00"
        "expenses:food","€200.00"
        "expenses:rent","€1200.00"
        """
        let result = HledgerBackend.parseCSVAccountBalances(csv)
        #expect(result.count == 3)
        #expect(result[0].0 == "assets:bank")
        #expect(result[2].0 == "expenses:rent")
    }

    @Test func parsesLargeBalance() {
        let csv = """
        "account","balance"
        "assets:bank","€1234567890.12"
        """
        let result = HledgerBackend.parseCSVAccountBalances(csv)
        #expect(result.count == 1)
        #expect(result[0].1 == "€1234567890.12")
    }

    @Test func headerOnlyReturnsEmpty() {
        let csv = "\"account\",\"balance\"\n"
        let result = HledgerBackend.parseCSVAccountBalances(csv)
        #expect(result.isEmpty)
    }

    @Test func multiCommodityBalanceKeptIntact() {
        // hledger CSV emits multi-commodity as "$120.00, €500.00" in a single field.
        // The parser keeps the field intact; resolution happens elsewhere.
        let csv = """
        "account","balance"
        "assets:bank","$120.00, €500.00"
        """
        let result = HledgerBackend.parseCSVAccountBalances(csv)
        #expect(result.count == 1)
        #expect(result[0].1.contains("$120"))
        #expect(result[0].1.contains("€500"))
    }
}

// MARK: - resolveMultiCommodityBalance

@Suite("HledgerBackend.resolveMultiCommodityBalance")
struct ResolveMultiCommodityBalanceTests {

    @Test func singleCommodityReturnsItself() {
        let (qty, com) = HledgerBackend.resolveMultiCommodityBalance("€500.00", preferredCommodity: "")
        #expect(qty == Decimal(string: "500"))
        #expect(com == "€")
    }

    @Test func multiCommodityWithPreferredPicksPreferred() {
        let (qty, com) = HledgerBackend.resolveMultiCommodityBalance(
            "$120.00, €500.00",
            preferredCommodity: "€"
        )
        #expect(com == "€")
        #expect(qty == Decimal(string: "500"))
    }

    @Test func multiCommodityWithPreferredAlsoMatchesFirst() {
        let (qty, com) = HledgerBackend.resolveMultiCommodityBalance(
            "$120.00, €500.00",
            preferredCommodity: "$"
        )
        #expect(com == "$")
        #expect(qty == Decimal(string: "120"))
    }

    @Test func multiCommodityNoPreferredFallsBackToFirstNonZero() {
        let (qty, com) = HledgerBackend.resolveMultiCommodityBalance(
            "$120.00, €500.00",
            preferredCommodity: ""
        )
        // First non-zero amount is picked
        #expect(com == "$")
        #expect(qty == Decimal(string: "120"))
    }

    @Test func emptyBalanceReturnsZero() {
        let (qty, com) = HledgerBackend.resolveMultiCommodityBalance("", preferredCommodity: "€")
        #expect(qty == 0)
        #expect(com == "")
    }
}
