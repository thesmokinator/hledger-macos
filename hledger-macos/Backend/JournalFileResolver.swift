/// Resolves the journal file path using a priority chain:
/// 1. User-configured path (from AppConfig) — file or directory
/// 2. LEDGER_FILE environment variable
/// 3. Default ~/.hledger.journal

import Foundation

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
    /// - Parameter configuredPath: User-configured path from settings (empty = not set).
    /// - Returns: The resolved file URL, or nil if no journal file is found.
    static func resolve(configuredPath: String = "") -> URL? {
        // 1. User-configured path
        if !configuredPath.isEmpty {
            if let url = resolvePathOrDirectory(configuredPath) {
                return url
            }
        }

        // 2. LEDGER_FILE environment variable
        if let envFile = ProcessInfo.processInfo.environment["LEDGER_FILE"], !envFile.isEmpty {
            if let url = resolvePathOrDirectory(envFile) {
                return url
            }
        }

        // 3. Default ~/.hledger.journal
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
