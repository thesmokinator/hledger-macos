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

    /// Get the prices file URL: return cache if fresh, fetch if stale.
    ///
    /// Returns `nil` for the URL if pricehist is not configured, no tickers are set,
    /// or all fetches failed. The second element of the tuple contains any ticker
    /// symbols for which no price data could be retrieved.
    static func getPricesFile(
        pricehistPath: String,
        tickers: [String: String]
    ) async -> (URL?, Set<String>) {
        guard !tickers.isEmpty else { return (nil, []) }
        guard isValid(path: pricehistPath) else { return (nil, []) }

        if pricesAreFresh(tickers: tickers) {
            return (cachePath, [])
        }

        let runner = SubprocessRunner(executablePath: pricehistPath)
        var lines: [String] = []
        var failed: Set<String> = []

        for (commodity, ticker) in tickers {
            do {
                if let directive = try await PriceFetcher.fetchLatestPrice(runner: runner, ticker: ticker, commodity: commodity) {
                    lines.append(directive)
                } else {
                    failed.insert(ticker)
                }
            } catch {
                failed.insert(ticker)
            }
        }

        guard !lines.isEmpty else { return (nil, failed) }

        do {
            let content = lines.joined(separator: "\n") + "\n"
            try content.write(to: cachePath, atomically: true, encoding: .utf8)
            try tickerHash(for: tickers).write(to: tickerHashPath, atomically: true, encoding: .utf8)
            return (cachePath, failed)
        } catch {
            return (nil, failed)
        }
    }
}
