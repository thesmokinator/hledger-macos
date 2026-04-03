/// Detects the hledger CLI binary on the system.

import Foundation

/// Result of hledger binary detection.
struct BinaryDetectionResult: Sendable {
    let hledgerPath: String?

    var isFound: Bool { hledgerPath != nil }
}

/// Scans for the hledger binary in known paths, user shell PATH, and configured locations.
enum BinaryDetector {
    /// Common installation paths on macOS.
    private static let knownPaths = [
        "/opt/homebrew/bin/hledger",    // Apple Silicon Homebrew
        "/usr/local/bin/hledger",       // Intel Homebrew
        "/usr/bin/hledger",             // System
    ]

    /// Detect the hledger binary.
    static func detect(customHledgerPath: String = "") -> BinaryDetectionResult {
        let path = findHledger(customPath: customHledgerPath)
        return BinaryDetectionResult(hledgerPath: path)
    }

    /// Find the hledger binary.
    static func findHledger(customPath: String = "") -> String? {
        // 1. User-configured custom path
        if !customPath.isEmpty,
           FileManager.default.isExecutableFile(atPath: customPath) {
            return customPath
        }

        // 2. Check known filesystem paths directly
        for path in knownPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // 3. Search user's shell PATH (covers stack, cabal, ghcup, nix, etc.)
        for path in shellPATHDirectories() {
            let candidate = (path as NSString).appendingPathComponent("hledger")
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }

    /// Get PATH directories from the user's login shell.
    /// GUI apps don't inherit the shell PATH, so we ask the shell explicitly.
    private static func shellPATHDirectories() -> [String] {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-l", "-c", "echo $PATH"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let pathString = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !pathString.isEmpty else { return [] }

            return pathString.split(separator: ":").map(String.init)
        } catch {
            return []
        }
    }
}
