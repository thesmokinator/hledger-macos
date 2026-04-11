/// Detects the hledger CLI binary and journal file path on the system.

import Foundation

/// Result of hledger binary detection.
struct BinaryDetectionResult: Sendable {
    let hledgerPath: String?
    /// Journal path resolved by asking hledger itself via a login shell.
    let detectedJournalPath: String?

    var isFound: Bool { hledgerPath != nil }
}

/// Abstraction for binary detection, enabling test injection.
protocol BinaryDetecting {
    func detect(customHledgerPath: String) -> BinaryDetectionResult
}

/// Production implementation that delegates to the default BinaryDetector.
struct LiveBinaryDetector: BinaryDetecting {
    func detect(customHledgerPath: String) -> BinaryDetectionResult {
        BinaryDetector().detect(customHledgerPath: customHledgerPath)
    }
}

// MARK: - Injection Protocols

/// Filesystem access surface used by BinaryDetector. Injected for testing.
protocol FileSystemAccess: Sendable {
    func isExecutableFile(atPath path: String) -> Bool
    func isDirectory(atPath path: String) -> Bool
}

/// Shell command runner used by BinaryDetector. Injected for testing.
protocol ShellRunner: Sendable {
    /// Run `shell` with `args` and return its stdout, or nil on failure / timeout.
    func run(shell: String, args: [String], timeout: TimeInterval) -> String?
}

/// Live FileSystemAccess that wraps `FileManager.default`.
struct LiveFileSystem: FileSystemAccess {
    func isExecutableFile(atPath path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }

    func isDirectory(atPath path: String) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }
}

/// Live ShellRunner that runs a real subprocess with a deadline.
struct LiveShell: ShellRunner {
    func run(shell: String, args: [String], timeout: TimeInterval) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let nanos = Int(timeout * 1_000_000_000)
        let deadline = DispatchTime.now() + .nanoseconds(nanos)
        let done = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in done.signal() }
        if done.wait(timeout: deadline) == .timedOut {
            process.terminate()
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - BinaryDetector

/// Scans for the hledger binary in known paths, user shell PATH, and configured locations.
/// Also detects the journal file by running `hledger files` in a login shell.
struct BinaryDetector {
    let fileSystem: FileSystemAccess
    let shell: ShellRunner
    /// Timeout for any single shell invocation, in seconds.
    let shellTimeout: TimeInterval

    init(
        fileSystem: FileSystemAccess = LiveFileSystem(),
        shell: ShellRunner = LiveShell(),
        shellTimeout: TimeInterval = 5
    ) {
        self.fileSystem = fileSystem
        self.shell = shell
        self.shellTimeout = shellTimeout
    }

    /// Common installation paths on macOS.
    private var knownPaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "/opt/homebrew/bin/hledger",          // Apple Silicon Homebrew
            "/usr/local/bin/hledger",             // Intel Homebrew / generic
            "/usr/bin/hledger",                   // System
            "\(home)/.local/bin/hledger",         // stack
            "\(home)/.cabal/bin/hledger",         // cabal
        ]
    }

    /// Detect the hledger binary and the journal file.
    func detect(customHledgerPath: String = "") -> BinaryDetectionResult {
        let hledgerPath = findHledger(customPath: customHledgerPath)
        let journalPath = hledgerPath.flatMap { journalPathFromHledger($0) }
        return BinaryDetectionResult(hledgerPath: hledgerPath, detectedJournalPath: journalPath)
    }

    /// Find the hledger binary.
    func findHledger(customPath: String = "") -> String? {
        // 1. User-configured custom path
        if !customPath.isEmpty,
           fileSystem.isExecutableFile(atPath: customPath) {
            return customPath
        }

        // 2. Check known filesystem paths directly
        for path in knownPaths {
            if fileSystem.isExecutableFile(atPath: path) {
                return path
            }
        }

        // 3. Search user's shell PATH (covers stack, cabal, ghcup, nix, etc.)
        for dir in loginShellPATH() {
            let candidate = (dir as NSString).appendingPathComponent("hledger")
            if fileSystem.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        return nil
    }

    /// Resolve the journal file by running `hledger files` in a login shell.
    ///
    /// Tries the user's configured shell first, then falls back to bash and zsh.
    /// Exotic shells (e.g. osh) may fail at step 1 — that's fine, bash/zsh cover it.
    func journalPathFromHledger(_ hledgerPath: String) -> String? {
        let userShell = ProcessInfo.processInfo.environment["SHELL"] ?? ""
        // Deduplicated list: user shell first, then standard fallbacks
        var shells = [userShell, "/bin/bash", "/bin/zsh"].filter { !$0.isEmpty }
        // Remove duplicates while preserving order
        var seen = Set<String>()
        shells = shells.filter { seen.insert($0).inserted }

        for sh in shells {
            guard let output = shell.run(shell: sh, args: ["-l", "-c", "\"\(hledgerPath)\" files"], timeout: shellTimeout),
                  let firstLine = output.split(separator: "\n").first.map(String.init) else { continue }
            let path = firstLine.trimmingCharacters(in: .whitespaces)
            if !path.isEmpty {
                return path
            }
        }
        return nil
    }

    /// PATH directories from the user's login shell.
    ///
    /// GUI apps don't inherit the shell PATH, so we ask the shell explicitly.
    func loginShellPATH() -> [String] {
        let sh = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        // Try interactive login (-li) first, then plain login (-l)
        for args in [["-li", "-c", "echo $PATH"], ["-l", "-c", "echo $PATH"]] {
            guard let output = shell.run(shell: sh, args: args, timeout: shellTimeout) else { continue }
            // Take the last non-empty line (shell may print motd or other output)
            let pathString = output.split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .last { $0.contains("/") && !$0.isEmpty }
            if let pathString, !pathString.isEmpty {
                return pathString.split(separator: ":").map(String.init)
            }
        }
        return []
    }
}

// MARK: - Static convenience

/// Backward-compatible static API that delegates to a default-initialized BinaryDetector.
extension BinaryDetector {
    static func detect(customHledgerPath: String = "") -> BinaryDetectionResult {
        BinaryDetector().detect(customHledgerPath: customHledgerPath)
    }

    static func findHledger(customPath: String = "") -> String? {
        BinaryDetector().findHledger(customPath: customPath)
    }

    static func journalPathFromHledger(_ hledgerPath: String) -> String? {
        BinaryDetector().journalPathFromHledger(hledgerPath)
    }

    static func loginShellPATH() -> [String] {
        BinaryDetector().loginShellPATH()
    }
}
