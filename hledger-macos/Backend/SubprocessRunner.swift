/// Async wrapper around Foundation.Process for running CLI commands.

import Foundation

/// Runs an external CLI binary and returns its stdout.
actor SubprocessRunner {
    let executablePath: String

    init(executablePath: String) {
        self.executablePath = executablePath
    }

    /// Run the executable with the given arguments and return stdout.
    ///
    /// - Parameter arguments: CLI arguments to pass to the executable.
    /// - Returns: The stdout output as a string.
    /// - Throws: `BackendError.binaryNotFound` if the executable doesn't exist,
    ///           `BackendError.commandFailed` if the process exits with non-zero status.
    @discardableResult
    func run(_ arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        var env = ProcessInfo.processInfo.environment
        let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        let currentPath = env["PATH"] ?? "/usr/bin:/bin"
        let allPaths = extraPaths + currentPath.split(separator: ":").map(String.init)
        env["PATH"] = allPaths.joined(separator: ":")
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Read data asynchronously BEFORE waiting for termination to avoid
        // pipe buffer deadlock when output is large.
        var stdoutData = Data()
        var stderrData = Data()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty {
                stdoutData.append(chunk)
            }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty {
                stderrData.append(chunk)
            }
        }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            throw BackendError.binaryNotFound(executablePath)
        }

        // Wait for process to finish
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { _ in
                // Read any remaining data
                stdoutData.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
                stderrData.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                let outStr = String(data: stdoutData, encoding: .utf8) ?? ""
                let errStr = String(data: stderrData, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: outStr)
                } else {
                    continuation.resume(
                        throwing: BackendError.commandFailed(
                            errStr.isEmpty
                                ? "Process exited with status \(process.terminationStatus)"
                                : errStr.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    )
                }
            }
        }
    }
}
