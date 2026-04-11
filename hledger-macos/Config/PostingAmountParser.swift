/// Parses posting amount strings entered by the user in transaction forms.
///
/// This is a higher-level parser than `AmountParser`: it returns a complete
/// `Amount` object (including optional cost annotation) instead of a simple
/// `(Decimal, String)` tuple. It's designed for user input in transaction
/// forms where cost annotations like `-5 XDWD @@ €742,55` are common.
///
/// Supported formats:
/// - Plain number:          `50.00`, `-50,00`
/// - Currency prefix:       `€50.00`, `-€50,00`, `€-50.00`
/// - Currency suffix:       `50.00 EUR`, `-50,00 EUR`
/// - Named commodity:       `-5 XDWD`, `10 AAPL`
/// - With total cost (@@):  `-5 XDWD @@ €742,55`
/// - With unit cost (@):    `-5 XDWD @ €148.518` (converted to total cost)
///
/// Handles both US (`1,000.00`) and European (`1.000,00`) number formats.
/// The returned `Amount` always uses `.` as decimal mark (the default), so
/// `Amount.formatted()` produces hledger-compatible output regardless of
/// whether the user typed `,` or `.`.

import Foundation

enum PostingAmountParser {

    // MARK: - Regex

    /// Matches a cost-annotated amount string.
    ///
    /// Groups: `(quantity)(commodity)(@@?)(cost)`
    /// Examples: `-1 SWDA @@ 112,93`, `-5 XDWD @@ €742.55`, `10 AAPL @ €22.50`
    private static let costRegex = /^(-?[\d.,]+)\s+([A-Za-z][A-Za-z0-9]*)\s+(@@?)\s+(.+)$/

    // MARK: - Public API

    /// Closure that resolves the journal-declared `AmountStyle` for a given commodity,
    /// or returns `nil` if the commodity is not declared (in which case the parser keeps
    /// its input-derived style). See `AppState.parseFormAmount(_:)` for the production
    /// resolver and issue #129 for the bug this guards against.
    typealias StyleResolver = (String) -> AmountStyle?

    /// Parse a posting amount string into an `Amount`.
    ///
    /// Tries the cost-annotated pattern first (`qty COMMODITY @@ cost`); falls
    /// back to simple amount parsing if no cost annotation is found.
    ///
    /// - Parameters:
    ///   - input: The raw user-entered amount string.
    ///   - defaultCommodity: Commodity to use when the input has no explicit one.
    ///   - styleResolver: Optional closure that returns the journal-declared
    ///     `AmountStyle` for a commodity. When provided and non-nil for the
    ///     resolved commodity, its `decimalMark`, `digitGroupSeparator`, and
    ///     `digitGroupSizes` override the input-derived defaults so that
    ///     `Amount.formatted()` produces a string hledger round-trips
    ///     correctly. See #129.
    /// - Returns: An `Amount` if parsing succeeds, `nil` otherwise.
    static func parse(
        _ input: String,
        defaultCommodity: String = "",
        styleResolver: StyleResolver? = nil
    ) -> Amount? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if let amount = parseCostAnnotated(trimmed, defaultCommodity: defaultCommodity, styleResolver: styleResolver) {
            return amount
        }
        return parseSimple(trimmed, defaultCommodity: defaultCommodity, styleResolver: styleResolver)
    }

    /// Parse a cost-annotated amount like `-5 XDWD @@ €742,55` or `-5 XDWD @ €148.518`.
    ///
    /// Returns `nil` if the input does not match the cost pattern or if either the
    /// quantity or the cost portion cannot be parsed.
    static func parseCostAnnotated(
        _ input: String,
        defaultCommodity: String = "",
        styleResolver: StyleResolver? = nil
    ) -> Amount? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard let match = trimmed.firstMatch(of: costRegex) else { return nil }

        let qtyStr = String(match.1)
        let commodity = String(match.2)
        let costOperator = String(match.3)
        let costStr = String(match.4).trimmingCharacters(in: .whitespaces)

        let qty = AmountParser.parseNumber(qtyStr)
        guard qty != 0 else { return nil }

        guard let costAmount = parseSimple(costStr, defaultCommodity: defaultCommodity, styleResolver: styleResolver) else {
            return nil
        }

        // Normalize to total cost: hledger's @ means unit cost, @@ means total cost.
        // Internally we always store total cost — this matches hledger-textual and
        // simplifies `Amount.formatted()` which always emits `@@`.
        let totalCostQty: Decimal
        if costOperator == "@" {
            totalCostQty = abs(costAmount.quantity * qty)
        } else {
            totalCostQty = abs(costAmount.quantity)
        }

        let cost = CostAmount(
            commodity: costAmount.commodity,
            quantity: totalCostQty,
            style: costAmount.style
        )

        var style = AmountStyle(
            commoditySide: .right,
            commoditySpaced: true,
            precision: decimalPlaces(in: qtyStr)
        )
        applyJournalStyle(&style, for: commodity, resolver: styleResolver)

        return Amount(commodity: commodity, quantity: qty, style: style, cost: cost)
    }

    /// Parse a simple amount (no cost annotation) like `€50.00`, `50,00 EUR`, or `50`.
    ///
    /// Returns `nil` for empty input or for plain `0` with no commodity (treated as
    /// "no amount", consistent with the existing TransactionFormView behaviour).
    static func parseSimple(
        _ input: String,
        defaultCommodity: String = "",
        styleResolver: StyleResolver? = nil
    ) -> Amount? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let (qty, commodity) = AmountParser.parse(trimmed)

        // Bail out for "no amount" inputs: empty result with no commodity.
        if qty == 0 && commodity.isEmpty { return nil }

        let effectiveCommodity = commodity.isEmpty ? defaultCommodity : commodity
        var style = styleFor(commodity: effectiveCommodity, rawInput: trimmed)
        applyJournalStyle(&style, for: effectiveCommodity, resolver: styleResolver)

        return Amount(commodity: effectiveCommodity, quantity: qty, style: style)
    }

    // MARK: - Helpers

    /// Build an `AmountStyle` for a parsed commodity, deriving every field from
    /// the raw input string so the user-typed shape round-trips intact even
    /// without a `styleResolver`.
    ///
    /// - Single-character commodities (e.g. `€`, `$`) are placed on the left with no space.
    /// - Multi-character commodities (e.g. `EUR`, `SWDA`) are placed on the right with a space.
    /// - `decimalMark` and `digitGroupSeparator` come from `detectFormat(in:)`,
    ///   so `1,00 €` produces `decimalMark = ","` even with no resolver and
    ///   `1.000,00` also gets `digitGroupSeparator = "."`. Callers can still
    ///   pass a `styleResolver` (via `applyJournalStyle`) to OVERRIDE the
    ///   input-derived values with the journal-declared style — that is the
    ///   safety net when the user types in the "wrong" format and we want to
    ///   normalise on save.
    private static func styleFor(commodity: String, rawInput: String) -> AmountStyle {
        let isSymbol = commodity.count == 1
        let format = detectFormat(in: rawInput)
        return AmountStyle(
            commoditySide: isSymbol ? .left : .right,
            commoditySpaced: !isSymbol,
            decimalMark: format.decimalMark,
            digitGroupSeparator: format.digitGroupSeparator,
            digitGroupSizes: format.digitGroupSeparator != nil ? [3] : [],
            precision: decimalPlaces(in: rawInput)
        )
    }

    /// Override the input-derived `decimalMark` / `digitGroupSeparator` /
    /// `digitGroupSizes` of `style` with the journal-declared style for
    /// `commodity` if the resolver returns a non-nil value. Side, spacing and
    /// input-derived precision are kept so the user-typed shape is preserved.
    ///
    /// This is the fix for #129: without it, an Amount written by the form
    /// uses `decimalMark = "."` and a journal that declares
    /// `commodity € 1.000,00` re-parses `€1.00` as `100`.
    private static func applyJournalStyle(
        _ style: inout AmountStyle,
        for commodity: String,
        resolver: StyleResolver?
    ) {
        guard let resolved = resolver?(commodity) else { return }
        style.decimalMark = resolved.decimalMark
        style.digitGroupSeparator = resolved.digitGroupSeparator
        style.digitGroupSizes = resolved.digitGroupSizes
    }

    /// Return the number of decimal places in a raw number string.
    ///
    /// Strips both leading and trailing non-numeric characters before
    /// counting, so inputs like `1,00 €` or `-1.234,56 EUR` work the same
    /// as `€1,00` and `-€1.234,56`. Without the trailing strip, `1,00 €`
    /// would return 0 because `"00 €"` is not all-numeric — that was the
    /// root cause of the precision-lost variant of #129.
    static func decimalPlaces(in s: String) -> Int {
        let core = stripNonNumericEdges(s)
        guard !core.isEmpty else { return 0 }

        let format = detectFormat(in: s)
        guard let lastMark = core.lastIndex(of: Character(format.decimalMark)) else { return 0 }
        // Count only digits after the decimal mark — any trailing non-digits
        // are already stripped by stripNonNumericEdges, but be defensive.
        return core[core.index(after: lastMark)...].filter(\.isNumber).count
    }

    /// Detect the decimal mark and (optional) digit-group separator from a raw
    /// number string, looking only at the leading/trailing-stripped numeric core.
    ///
    /// - Both `.` and `,` present: the **last** one is the decimal mark, the
    ///   other is the digit-group separator (`1.000,00` → European,
    ///   `1,000.00` → US).
    /// - Only `,` present: it is the decimal mark when ≤2 digits follow it
    ///   (`50,00`), otherwise it is interpreted as a thousands separator
    ///   (`1,000` → 1000 with `","` digit group, no fractional part).
    /// - Only `.` present, or neither: `.` is the decimal mark, no group
    ///   separator.
    static func detectFormat(in s: String) -> (decimalMark: String, digitGroupSeparator: String?) {
        let core = stripNonNumericEdges(s)
        let hasDot = core.contains(".")
        let hasComma = core.contains(",")

        if hasDot && hasComma {
            let lastDot = core.lastIndex(of: ".")!
            let lastComma = core.lastIndex(of: ",")!
            if lastComma > lastDot {
                return (decimalMark: ",", digitGroupSeparator: ".")
            } else {
                return (decimalMark: ".", digitGroupSeparator: ",")
            }
        }

        if hasComma {
            let lastComma = core.lastIndex(of: ",")!
            let afterComma = core[core.index(after: lastComma)...]
            if afterComma.count <= 2 && afterComma.allSatisfy(\.isNumber) {
                return (decimalMark: ",", digitGroupSeparator: nil)
            } else {
                return (decimalMark: ".", digitGroupSeparator: ",")
            }
        }

        return (decimalMark: ".", digitGroupSeparator: nil)
    }

    /// Strip non-numeric characters from BOTH ends of a literal amount string,
    /// leaving only the contiguous numeric core (digits, `.`, `,` and any
    /// embedded `-` for the sign which is treated as numeric here too).
    private static func stripNonNumericEdges(_ s: String) -> Substring {
        var core = Substring(s)
        while let first = core.first, !first.isNumber && first != "." && first != "," {
            core = core.dropFirst()
        }
        while let last = core.last, !last.isNumber && last != "." && last != "," {
            core = core.dropLast()
        }
        return core
    }
}
