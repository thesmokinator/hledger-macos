/// Async wrapper around Foundation.Process for running CLI commands.

import Foundation

/// Thread-safe data accumulator for pipe output.
nonisolated private final class DataAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    func finalize(_ remaining: Data) -> Data {
        lock.lock()
        data.append(remaining)
        let result = data
        lock.unlock()
        return result
    }
}

/// Runs an external CLI binary and returns its stdout.
actor SubprocessRunner {
    let executablePath: String

    init(executablePath: String) {
        self.executablePath = executablePath
    }

    /// Run the executable with the given arguments and return stdout.
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

        let stdoutAccumulator = DataAccumulator()
        let stderrAccumulator = DataAccumulator()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty { stdoutAccumulator.append(chunk) }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty { stderrAccumulator.append(chunk) }
        }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            throw BackendError.binaryNotFound(executablePath)
        }

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { _ in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                let outData = stdoutAccumulator.finalize(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
                let errData = stderrAccumulator.finalize(stderrPipe.fileHandleForReading.readDataToEndOfFile())

                let outStr = String(data: outData, encoding: .utf8) ?? ""
                let errStr = String(data: errData, encoding: .utf8) ?? ""

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
