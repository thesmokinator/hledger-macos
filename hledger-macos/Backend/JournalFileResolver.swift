/// Resolves the journal file path using a priority chain:
/// 1. User-configured path (from AppConfig) — file or directory
/// 2. LEDGER_FILE environment variable (process environment)
/// 3. Shell-detected path from `hledger files` (covers LEDGER_FILE set in shell config)
/// 4. Default ~/.hledger.journal

import Foundation

/// Abstraction for journal file resolution, enabling test injection.
protocol JournalResolving {
    func resolve(configuredPath: String, shellDetectedPath: String?) -> URL?
}

/// Production implementation that delegates to the static JournalFileResolver methods.
struct LiveJournalResolver: JournalResolving {
    func resolve(configuredPath: String, shellDetectedPath: String?) -> URL? {
        JournalFileResolver.resolve(configuredPath: configuredPath, shellDetectedPath: shellDetectedPath)
    }
}

enum JournalFileResolver {
    /// Common journal file names to look for inside a directory.
    private static let knownJournalNames = [
        "main.journal",
        "all.journal",
        "hledger.journal",
        ".hledger.journal",
        "main.hledger",
        "default.journal",
    ]

    /// Supported journal file extensions.
    private static let journalExtensions: Set<String> = [
        "journal", "hledger", "j",
    ]

    /// Resolve the journal file path.
    ///
    /// Accepts either a file path or a directory. If a directory is given,
    /// searches for common journal file names inside it.
    ///
    /// - Parameters:
    ///   - configuredPath: User-configured path from settings (empty = not set).
    ///   - shellDetectedPath: Path returned by `hledger files` via login shell (nil = not available).
    /// - Returns: The resolved file URL, or nil if no journal file is found.
    static func resolve(configuredPath: String = "", shellDetectedPath: String? = nil) -> URL? {
        // 1. User-configured path
        if !configuredPath.isEmpty {
            if let url = resolvePathOrDirectory(configuredPath) {
                return url
            }
        }

        // 2. LEDGER_FILE from process environment
        if let envFile = ProcessInfo.processInfo.environment["LEDGER_FILE"], !envFile.isEmpty {
            if let url = resolvePathOrDirectory(envFile) {
                return url
            }
        }

        // 3. Shell-detected path from `hledger files` — covers LEDGER_FILE set in shell config,
        //    hledger config files, and any other hledger-native configuration.
        if let shellPath = shellDetectedPath, !shellPath.isEmpty {
            if let url = resolvePathOrDirectory(shellPath) {
                return url
            }
        }

        // 4. Default ~/.hledger.journal
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let defaultFile = homeDir.appendingPathComponent(".hledger.journal")
        if FileManager.default.fileExists(atPath: defaultFile.path) {
            return defaultFile
        }

        return nil
    }

    /// Resolve a path that may be a file or a directory.
    private static func resolvePathOrDirectory(_ path: String) -> URL? {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return nil
        }

        if !isDir.boolValue {
            // It's a file — use it directly
            return url
        }

        // It's a directory — search for known journal files
        for name in knownJournalNames {
            let candidate = url.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        // Fall back: find any .journal file in the directory
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: url.path) {
            let journalFiles = contents.filter { file in
                let ext = (file as NSString).pathExtension.lowercased()
                return journalExtensions.contains(ext)
            }.sorted()

            if let first = journalFiles.first {
                return url.appendingPathComponent(first)
            }
        }

        return nil
    }

    /// Return the default/detected journal file path as a string (for pre-filling UI).
    static func defaultPath() -> String {
        if let envFile = ProcessInfo.processInfo.environment["LEDGER_FILE"], !envFile.isEmpty {
            return envFile
        }

        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let defaultFile = homeDir.appendingPathComponent(".hledger.journal")
        if FileManager.default.fileExists(atPath: defaultFile.path) {
            return defaultFile.path
        }

        return "~/.hledger.journal"
    }
}
