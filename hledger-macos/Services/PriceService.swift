/// Fetches market prices via pricehist CLI and caches them as hledger P-directives.

import Foundation

enum PriceService {
    /// Cache file for daily prices.
    private static var cachePath: URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("hledger-macos")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return cacheDir.appendingPathComponent("prices.journal")
    }

    /// Path to store the ticker hash for cache invalidation.
    private static var tickerHashPath: URL {
        cachePath.deletingLastPathComponent().appendingPathComponent("tickers.hash")
    }

    /// Compute a stable hash of the tickers configuration.
    private static func tickerHash(for tickers: [String: String]) -> String {
        let sorted = tickers.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
        return sorted
    }

    /// Check if cached prices are fresh (written today and tickers unchanged).
    static func pricesAreFresh(tickers: [String: String]) -> Bool {
        guard FileManager.default.fileExists(atPath: cachePath.path) else { return false }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: cachePath.path),
              let mtime = attrs[.modificationDate] as? Date else { return false }
        guard Calendar.current.isDateInToday(mtime) else { return false }
        // Check tickers haven't changed since last fetch
        guard let savedHash = try? String(contentsOf: tickerHashPath, encoding: .utf8) else { return false }
        return savedHash == tickerHash(for: tickers)
    }

    /// Invalidate the cached prices file.
    static func invalidateCache() {
        try? FileManager.default.removeItem(at: cachePath)
        try? FileManager.default.removeItem(at: tickerHashPath)
    }

    /// Check if a pricehist path is valid (file exists and is executable).
    static func isValid(path: String) -> Bool {
        !path.isEmpty && FileManager.default.isExecutableFile(atPath: path)
    }

    /// Clean pricehist output: remove timestamps and limit decimal precision.
    private static func cleanPDirective(_ line: String) -> String {
        // pricehist outputs: P 2026-04-02 00:00:00 SWDA 112.73999786 EUR
        // hledger expects:  P 2026-04-02 SWDA 112.74 EUR
        var parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        // Remove timestamp (HH:MM:SS) if present after date
        if parts.count >= 3 && parts[2].contains(":") {
            parts.remove(at: 2)
        }
        // Round price to 2 decimals if it's a number
        if parts.count >= 4, let price = Double(parts[3]) {
            parts[3] = String(format: "%.2f", price)
        }
        return parts.joined(separator: " ")
    }

    /// Get the prices file URL: return cache if fresh, fetch if stale.
    /// Returns nil if pricehist path is not configured/valid or no tickers configured.
    static func getPricesFile(pricehistPath: String, tickers: [String: String]) async -> URL? {
        guard !tickers.isEmpty else { return nil }
        guard isValid(path: pricehistPath) else { return nil }

        if pricesAreFresh(tickers: tickers) {
            return cachePath
        }

        let runner = SubprocessRunner(executablePath: pricehistPath)
        let today = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()

        var lines: [String] = []

        for (commodity, ticker) in tickers {
            do {
                let output = try await runner.run([
                    "fetch", "yahoo", ticker,
                    "-s", today, "-e", today,
                    "-o", "ledger",
                    "--fmt-base", commodity
                ])
                for line in output.split(separator: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        lines.append(cleanPDirective(trimmed))
                    }
                }
            } catch {
                continue
            }
        }

        guard !lines.isEmpty else { return nil }

        do {
            let content = lines.joined(separator: "\n") + "\n"
            try content.write(to: cachePath, atomically: true, encoding: .utf8)
            try tickerHash(for: tickers).write(to: tickerHashPath, atomically: true, encoding: .utf8)
            return cachePath
        } catch {
            return nil
        }
    }
}
