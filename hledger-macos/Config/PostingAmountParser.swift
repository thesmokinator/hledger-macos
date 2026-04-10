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

    /// Parse a posting amount string into an `Amount`.
    ///
    /// Tries the cost-annotated pattern first (`qty COMMODITY @@ cost`); falls
    /// back to simple amount parsing if no cost annotation is found.
    ///
    /// - Parameters:
    ///   - input: The raw user-entered amount string.
    ///   - defaultCommodity: Commodity to use when the input has no explicit one.
    /// - Returns: An `Amount` if parsing succeeds, `nil` otherwise.
    static func parse(_ input: String, defaultCommodity: String = "") -> Amount? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if let amount = parseCostAnnotated(trimmed, defaultCommodity: defaultCommodity) {
            return amount
        }
        return parseSimple(trimmed, defaultCommodity: defaultCommodity)
    }

    /// Parse a cost-annotated amount like `-5 XDWD @@ €742,55` or `-5 XDWD @ €148.518`.
    ///
    /// Returns `nil` if the input does not match the cost pattern or if either the
    /// quantity or the cost portion cannot be parsed.
    static func parseCostAnnotated(_ input: String, defaultCommodity: String = "") -> Amount? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard let match = trimmed.firstMatch(of: costRegex) else { return nil }

        let qtyStr = String(match.1)
        let commodity = String(match.2)
        let costOperator = String(match.3)
        let costStr = String(match.4).trimmingCharacters(in: .whitespaces)

        let qty = AmountParser.parseNumber(qtyStr)
        guard qty != 0 else { return nil }

        guard let costAmount = parseSimple(costStr, defaultCommodity: defaultCommodity) else {
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

        let style = AmountStyle(
            commoditySide: .right,
            commoditySpaced: true,
            precision: decimalPlaces(in: qtyStr)
        )

        return Amount(commodity: commodity, quantity: qty, style: style, cost: cost)
    }

    /// Parse a simple amount (no cost annotation) like `€50.00`, `50,00 EUR`, or `50`.
    ///
    /// Returns `nil` for empty input or for plain `0` with no commodity (treated as
    /// "no amount", consistent with the existing TransactionFormView behaviour).
    static func parseSimple(_ input: String, defaultCommodity: String = "") -> Amount? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let (qty, commodity) = AmountParser.parse(trimmed)

        // Bail out for "no amount" inputs: empty result with no commodity.
        if qty == 0 && commodity.isEmpty { return nil }

        let effectiveCommodity = commodity.isEmpty ? defaultCommodity : commodity
        let style = styleFor(commodity: effectiveCommodity, rawInput: trimmed)

        return Amount(commodity: effectiveCommodity, quantity: qty, style: style)
    }

    // MARK: - Helpers

    /// Build an `AmountStyle` for a parsed commodity, deriving side, spacing and
    /// precision from the raw input string.
    ///
    /// - Single-character commodities (e.g. `€`, `$`) are placed on the left with no space.
    /// - Multi-character commodities (e.g. `EUR`, `SWDA`) are placed on the right with a space.
    /// - `decimalMark` is always `.` (the hledger default) so `Amount.formatted()`
    ///   produces hledger-compatible output.
    private static func styleFor(commodity: String, rawInput: String) -> AmountStyle {
        let isSymbol = commodity.count == 1
        return AmountStyle(
            commoditySide: isSymbol ? .left : .right,
            commoditySpaced: !isSymbol,
            precision: decimalPlaces(in: rawInput)
        )
    }

    /// Return the number of decimal places in a raw number string.
    ///
    /// Handles both US (`1,000.00`) and European (`1.000,00`) formats using the
    /// same heuristic as `AmountParser.parseNumber`:
    /// - If both `.` and `,` are present, the last one is the decimal mark.
    /// - If only `,` is present, it's treated as decimal when ≤2 digits follow,
    ///   otherwise as a thousands separator.
    /// - If only `.` is present, it's always the decimal mark.
    static func decimalPlaces(in s: String) -> Int {
        // Strip leading minus and any non-numeric prefix (e.g. currency symbol)
        let core = s.drop(while: { !$0.isNumber && $0 != "." && $0 != "," })
        guard !core.isEmpty else { return 0 }

        let hasDot = core.contains(".")
        let hasComma = core.contains(",")
        guard hasDot || hasComma else { return 0 }

        let decimalMark: Character
        if hasDot && hasComma {
            let lastDot = core.lastIndex(of: ".")!
            let lastComma = core.lastIndex(of: ",")!
            decimalMark = lastComma > lastDot ? "," : "."
        } else if hasComma {
            let lastComma = core.lastIndex(of: ",")!
            let afterComma = core[core.index(after: lastComma)...]
            // ≤2 digits after comma → decimal; otherwise thousands separator
            guard afterComma.count <= 2 && afterComma.allSatisfy(\.isNumber) else { return 0 }
            decimalMark = ","
        } else {
            decimalMark = "."
        }

        guard let lastMark = core.lastIndex(of: decimalMark) else { return 0 }
        return core.distance(from: core.index(after: lastMark), to: core.endIndex)
    }
}
