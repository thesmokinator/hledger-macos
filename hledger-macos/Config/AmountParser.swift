/// Shared utility for parsing amount strings like "€500.00" or "500.00 EUR".
/// Used by views and backends alike.

import Foundation

enum AmountParser {
    /// Parse an amount string into (quantity, commodity).
    /// Handles left-side currency ("€500.00"), right-side ("500.00 EUR"), and plain numbers.
    static func parse(_ s: String) -> (Decimal, String) {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != "0" else { return (0, "") }

        // Left-side commodity: €500.00
        if let match = trimmed.firstMatch(of: /^([^\d\s.\-]+)\s*(-?[\d,.]+)$/) {
            let commodity = String(match.1)
            let numStr = String(match.2).replacingOccurrences(of: ",", with: "")
            return (Decimal(string: numStr) ?? 0, commodity)
        }

        // Right-side commodity: 500.00 EUR
        if let match = trimmed.firstMatch(of: /^(-?[\d,.]+)\s*([^\d\s.\-]+)$/) {
            let numStr = String(match.1).replacingOccurrences(of: ",", with: "")
            let commodity = String(match.2)
            return (Decimal(string: numStr) ?? 0, commodity)
        }

        // Plain number
        let numStr = trimmed.replacingOccurrences(of: ",", with: "")
        return (Decimal(string: numStr) ?? 0, "")
    }
}
