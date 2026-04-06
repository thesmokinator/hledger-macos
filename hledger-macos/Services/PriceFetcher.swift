/// Helper for fetching the most recent available market price via pricehist.
///
/// Instead of querying a single date (which fails on weekends/holidays), fetches
/// a lookback window and extracts the most recent trading day's price directive.

import Foundation

enum PriceFetcher {
    /// Parse the most recent P-directive from pricehist ledger output.
    ///
    /// pricehist may return multiple lines (one per trading day in the range).
    /// This function returns only the last non-empty line, cleaned for hledger.
    static func parseLatestDirective(from output: String) -> String? {
        output.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .last
            .map(cleanPDirective)
    }

    /// Fetch the most recent trading day price for a ticker within the last `lookbackDays` days.
    ///
    /// Uses a date range instead of a single date so that weekends and public holidays
    /// are handled transparently — pricehist returns all available trading days in the
    /// range and we take the latest one.
    ///
    /// - Parameters:
    ///   - runner: Configured `SubprocessRunner` pointing to the pricehist binary.
    ///   - ticker: Yahoo Finance ticker symbol (e.g. "XEON.MI").
    ///   - commodity: hledger commodity name to use in the P-directive (e.g. "XEON").
    ///   - lookbackDays: How many calendar days back to search. Defaults to 7,
    ///     which covers weekends and most national holiday gaps.
    /// - Returns: A cleaned hledger P-directive string, or `nil` if no data was found.
    static func fetchLatestPrice(
        runner: SubprocessRunner,
        ticker: String,
        commodity: String,
        lookbackDays: Int = 7
    ) async throws -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let end = formatter.string(from: .now)
        let startDate = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: .now)!
        let start = formatter.string(from: startDate)

        let output = try await runner.run([
            "fetch", "yahoo", ticker,
            "-s", start, "-e", end,
            "-o", "ledger",
            "--fmt-base", commodity
        ])

        return parseLatestDirective(from: output)
    }

    /// Clean a single pricehist P-directive for hledger compatibility.
    ///
    /// pricehist outputs: `P 2026-04-02 00:00:00 SWDA 112.73999786 EUR`
    /// hledger expects:   `P 2026-04-02 SWDA 112.74 EUR`
    static func cleanPDirective(_ line: String) -> String {
        var parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        // Remove timestamp (HH:MM:SS) after the date if present
        if parts.count >= 3 && parts[2].contains(":") {
            parts.remove(at: 2)
        }
        // Round price to 2 decimal places
        if parts.count >= 4, let price = Double(parts[3]) {
            parts[3] = String(format: "%.2f", price)
        }
        return parts.joined(separator: " ")
    }
}
