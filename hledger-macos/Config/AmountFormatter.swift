/// Centralized amount formatting utility.
/// Uses the system locale for decimal/grouping separators.

import Foundation

enum AmountFormatter {
    /// Shared NumberFormatter configured with system locale.
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        // Uses system locale by default (e.g. it_IT → 1.234,56)
        return f
    }()

    /// Format a Decimal amount with commodity symbol.
    ///
    /// - Currency symbols (single char like €, $, £) go on the left: €1.234,56
    /// - Named commodities (XEON, EUR, USD with 3+ chars) go on the right: 1.234,56 EUR
    static func format(_ amount: Decimal, commodity: String) -> String {
        let numStr = formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        if isCurrencySymbol(commodity) {
            return "\(commodity)\(numStr)"
        }
        return "\(numStr) \(commodity)"
    }

    /// Format a Decimal amount without commodity.
    static func formatNumber(_ amount: Decimal) -> String {
        formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    /// Format a quantity (up to 4 decimals, no trailing zeros).
    static func formatQuantity(_ qty: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 4
        f.minimumFractionDigits = 0
        return f.string(from: qty as NSDecimalNumber) ?? "\(qty)"
    }

    /// Determine if a commodity string is a currency symbol (left-side placement).
    private static func isCurrencySymbol(_ commodity: String) -> Bool {
        guard commodity.count == 1 else { return false }
        guard let c = commodity.first else { return false }
        return !c.isLetter && !c.isNumber
    }
}
