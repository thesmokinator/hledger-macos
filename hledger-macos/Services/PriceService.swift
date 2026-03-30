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

    /// Check if cached prices are fresh (written today).
    static func pricesAreFresh() -> Bool {
        guard FileManager.default.fileExists(atPath: cachePath.path) else { return false }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: cachePath.path),
              let mtime = attrs[.modificationDate] as? Date else { return false }
        return Calendar.current.isDateInToday(mtime)
    }

    /// Check if a pricehist path is valid (file exists and is executable).
    static func isValid(path: String) -> Bool {
        !path.isEmpty && FileManager.default.isExecutableFile(atPath: path)
    }

    /// Get the prices file URL: return cache if fresh, fetch if stale.
    /// Returns nil if pricehist path is not configured/valid or no tickers configured.
    static func getPricesFile(pricehistPath: String, tickers: [String: String]) async -> URL? {
        guard !tickers.isEmpty else { return nil }
        guard isValid(path: pricehistPath) else { return nil }

        if pricesAreFresh() {
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
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    lines.append(trimmed)
                }
            } catch {
                continue
            }
        }

        guard !lines.isEmpty else { return nil }

        do {
            let content = lines.joined(separator: "\n") + "\n"
            try content.write(to: cachePath, atomically: true, encoding: .utf8)
            return cachePath
        } catch {
            return nil
        }
    }
}
