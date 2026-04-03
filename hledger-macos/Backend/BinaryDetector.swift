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
    private static var knownPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "/opt/homebrew/bin/hledger",          // Apple Silicon Homebrew
            "/usr/local/bin/hledger",             // Intel Homebrew
            "/usr/bin/hledger",                   // System
            "\(home)/.local/bin/hledger",         // stack install
            "\(home)/.ghcup/bin/hledger",         // ghcup
            "\(home)/.cabal/bin/hledger",         // cabal install
            "/nix/var/nix/profiles/default/bin/hledger",  // Nix system
            "\(home)/.nix-profile/bin/hledger",   // Nix user
        ]
    }

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

        // Try both interactive login (-li) and plain login (-l) for maximum compatibility
        for args in [["-li", "-c", "echo $PATH"], ["-l", "-c", "echo $PATH"]] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: shell)
            process.arguments = args

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                // Timeout after 5 seconds to avoid hanging on interactive shells
                let deadline = DispatchTime.now() + .seconds(5)
                let done = DispatchSemaphore(value: 0)
                process.terminationHandler = { _ in done.signal() }
                if done.wait(timeout: deadline) == .timedOut {
                    process.terminate()
                    continue
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8) else { continue }
                // Take last non-empty line (shell might print motd or other output)
                let pathString = output.split(separator: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .last { $0.contains("/") && !$0.isEmpty }
                guard let pathString, !pathString.isEmpty else { continue }
                return pathString.split(separator: ":").map(String.init)
            } catch {
                continue
            }
        }
        return []
    }
}
