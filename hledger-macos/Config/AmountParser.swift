/// Shared utility for parsing amount strings like "€500.00", "€500,00", or "500.00 EUR".
/// Handles both US (1,000.00) and European (1.000,00) number formats.

import Foundation

enum AmountParser {
    /// Parse an amount string into (quantity, commodity).
    static func parse(_ s: String) -> (Decimal, String) {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != "0" else { return (0, "") }

        // Left-side commodity: €500.00 or €500,00
        if let match = trimmed.firstMatch(of: /^([^\d\s.\-]+)\s*(-?[\d.,]+)$/) {
            let commodity = String(match.1)
            let qty = parseNumber(String(match.2))
            return (qty, commodity)
        }

        // Right-side commodity: 500.00 EUR or 500,00 EUR
        if let match = trimmed.firstMatch(of: /^(-?[\d.,]+)\s*([^\d\s.\-]+)$/) {
            let qty = parseNumber(String(match.1))
            let commodity = String(match.2)
            return (qty, commodity)
        }

        // Plain number
        return (parseNumber(trimmed), "")
    }

    /// Parse a number string handling both US and European formats.
    /// - "1,000.00" → 1000.00 (US: comma = thousands, dot = decimal)
    /// - "1.000,00" → 1000.00 (EU: dot = thousands, comma = decimal)
    /// - "500.00"   → 500.00  (dot = decimal)
    /// - "500,00"   → 500.00  (comma = decimal)
    /// - "1000"     → 1000
    static func parseNumber(_ s: String) -> Decimal {
        let str = s.trimmingCharacters(in: .whitespaces)
        guard !str.isEmpty else { return 0 }

        let hasDot = str.contains(".")
        let hasComma = str.contains(",")

        let normalized: String

        if hasDot && hasComma {
            // Both present: last one is the decimal separator
            if let lastDot = str.lastIndex(of: "."), let lastComma = str.lastIndex(of: ",") {
                if lastComma > lastDot {
                    // European: 1.000,00 → dot is thousands, comma is decimal
                    normalized = str.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                } else {
                    // US: 1,000.00 → comma is thousands, dot is decimal
                    normalized = str.replacingOccurrences(of: ",", with: "")
                }
            } else {
                normalized = str.replacingOccurrences(of: ",", with: "")
            }
        } else if hasComma {
            // Only comma: could be decimal (500,00) or thousands (1,000)
            // Heuristic: if exactly 2 digits after last comma, treat as decimal
            if let lastComma = str.lastIndex(of: ",") {
                let afterComma = str[str.index(after: lastComma)...]
                if afterComma.count <= 2 && afterComma.allSatisfy(\.isNumber) {
                    // Decimal: 500,00 → 500.00
                    normalized = str.replacingOccurrences(of: ",", with: ".")
                } else {
                    // Thousands: 1,000 → 1000
                    normalized = str.replacingOccurrences(of: ",", with: "")
                }
            } else {
                normalized = str
            }
        } else {
            // Only dot or no separator: treat as-is
            normalized = str
        }

        return Decimal(string: normalized) ?? 0
    }
}
