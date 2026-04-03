/// Centralized log of all hledger commands executed by the app.

import Foundation

/// A single logged command execution.
struct CommandLogEntry: Identifiable, Hashable {
    static func == (lhs: CommandLogEntry, rhs: CommandLogEntry) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id = UUID()
    let timestamp: Date
    let command: String
    let exitCode: Int32
    let stdout: String
    let stderr: String

    var isError: Bool { exitCode != 0 }

    var timestampFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: timestamp)
    }
}

/// Observable command log shared across the app.
@Observable
@MainActor
final class CommandLog {
    static let shared = CommandLog()

    private(set) var entries: [CommandLogEntry] = []

    func log(command: String, exitCode: Int32, stdout: String, stderr: String) {
        let entry = CommandLogEntry(
            timestamp: Date(),
            command: command,
            exitCode: exitCode,
            stdout: stdout,
            stderr: stderr
        )
        entries.append(entry)
        // Keep last 500 entries
        if entries.count > 500 {
            entries.removeFirst(entries.count - 500)
        }
    }

    func clear() {
        entries.removeAll()
    }

    var errorCount: Int {
        entries.count(where: \.isError)
    }
}
