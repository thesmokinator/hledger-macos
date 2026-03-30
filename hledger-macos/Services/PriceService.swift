/// Fetches market prices via pricehist CLI and caches them as hledger P-directives.
///
/// Ported from hledger-textual/prices.py.

import Foundation

enum PriceService {
    /// Cache file for daily prices.
    private static var cachePath: URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("hledger-macos")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return cacheDir.appendingPathComponent("prices.journal")
    }

    /// Check if pricehist is installed.
    static func hasPricehist() -> Bool {
        BinaryDetector.findHledger(customPath: "") != nil // reuse detection pattern
        // Actually check for pricehist specifically
        || findPricehist() != nil
    }

    /// Find pricehist binary path.
    static func findPricehist() -> String? {
        let knownPaths = [
            "/opt/homebrew/bin/pricehist",
            "/usr/local/bin/pricehist",
        ]
        for path in knownPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        // Check in Python user bin paths
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let pyUserBin = homeDir.appendingPathComponent(".local/bin/pricehist")
        if FileManager.default.fileExists(atPath: pyUserBin.path) {
            return pyUserBin.path
        }
        return nil
    }

    /// Check if cached prices are fresh (written today).
    static func pricesAreFresh() -> Bool {
        guard FileManager.default.fileExists(atPath: cachePath.path) else { return false }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: cachePath.path),
              let mtime = attrs[.modificationDate] as? Date else { return false }
        return Calendar.current.isDateInToday(mtime)
    }

    /// Get the prices file URL: return cache if fresh, fetch if stale.
    /// Returns nil if pricehist is unavailable or no tickers configured.
    static func getPricesFile(tickers: [String: String]) async -> URL? {
        guard !tickers.isEmpty else { return nil }

        if pricesAreFresh() {
            return cachePath
        }

        guard let prichistPath = findPricehist() else { return nil }

        let runner = SubprocessRunner(executablePath: prichistPath)
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
                // Skip failed tickers silently
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
