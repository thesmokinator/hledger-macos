/// Journal file manipulation: append, replace, and delete transactions.
///
/// All write operations follow a safe pattern:
/// 1. Create a backup of the journal file (.bak)
/// 2. Perform the modification
/// 3. Validate with `hledger check`
/// 4. On failure, restore from backup
///
/// Ported from hledger-textual/journal.py.

import Foundation
import RegexBuilder

enum JournalWriter {
    // MARK: - Routing Strategy

    enum RoutingStrategy {
        case glob([String])     // include YYYY/*.journal — year strings
        case flat([String])     // include YYYY-MM.journal — filenames
        case fallback           // no date-based includes
    }

    // MARK: - Append

    /// Append a new transaction to the journal, auto-detecting routing strategy.
    static func append(
        transaction: Transaction,
        mainJournal: URL,
        validator: any AccountingBackend
    ) async throws {
        let content = try String(contentsOf: mainJournal, encoding: .utf8)
        let strategy = detectRoutingStrategy(content)

        switch strategy {
        case .fallback:
            try await appendToFile(
                transaction: transaction,
                targetFile: mainJournal,
                mainJournal: mainJournal,
                validator: validator
            )

        case .flat(let matches):
            let targetName = targetSubjournalName(for: transaction)
            let targetFile = mainJournal.deletingLastPathComponent().appendingPathComponent(targetName)
            if matches.contains(targetName) {
                try await appendToFile(
                    transaction: transaction,
                    targetFile: targetFile,
                    mainJournal: mainJournal,
                    validator: validator
                )
            } else {
                try await appendToNewSubjournal(
                    transaction: transaction,
                    targetFile: targetFile,
                    targetName: targetName,
                    mainJournal: mainJournal,
                    validator: validator
                )
            }

        case .glob(let years):
            let (targetFile, year) = globTargetPath(mainJournal: mainJournal, transaction: transaction)
            if FileManager.default.fileExists(atPath: targetFile.path) {
                try await appendToFile(
                    transaction: transaction,
                    targetFile: targetFile,
                    mainJournal: mainJournal,
                    validator: validator
                )
            } else if years.contains(year) {
                try await appendToNewGlobSubjournal(
                    transaction: transaction,
                    targetFile: targetFile,
                    mainJournal: mainJournal,
                    validator: validator
                )
            } else {
                try await appendToNewGlobYear(
                    transaction: transaction,
                    targetFile: targetFile,
                    year: year,
                    mainJournal: mainJournal,
                    validator: validator
                )
            }
        }
    }

    // MARK: - Replace

    /// Replace an existing transaction in the journal using source positions.
    static func replace(
        original: Transaction,
        with new: Transaction,
        mainJournal: URL,
        validator: any AccountingBackend
    ) async throws {
        guard let startPos = original.sourcePosStart, let endPos = original.sourcePosEnd else {
            throw BackendError.commandFailed("Cannot replace transaction without source position")
        }

        let sourceFile = URL(fileURLWithPath: startPos.sourceName)
        let backup = backupPath(for: sourceFile)

        try createBackup(source: sourceFile, backup: backup)

        do {
            var lines = try String(contentsOf: sourceFile, encoding: .utf8)
                .components(separatedBy: "\n")

            let startLine = startPos.sourceLine - 1
            let endLine = endPos.sourceLine - 1

            let newText = TransactionFormatter.format(new)
            let newLines = newText.components(separatedBy: "\n")

            lines.replaceSubrange(startLine..<endLine, with: newLines)
            try lines.joined(separator: "\n").write(to: sourceFile, atomically: true, encoding: .utf8)

            try await validate(mainJournal: mainJournal, sourceFile: sourceFile, backup: backup, validator: validator)
        } catch let error as BackendError {
            throw error
        } catch {
            restoreBackup(source: sourceFile, backup: backup)
            cleanupBackup(backup)
            throw BackendError.commandFailed("Failed to replace transaction: \(error.localizedDescription)")
        }
    }

    // MARK: - Status Toggle

    /// Update only the status marker on a transaction's date line.
    /// Much safer than full replace — doesn't re-format postings or amounts.
    static func updateStatus(
        transaction: Transaction,
        newStatus: TransactionStatus,
        mainJournal: URL,
        validator: any AccountingBackend
    ) async throws {
        guard let startPos = transaction.sourcePosStart else {
            throw BackendError.commandFailed("Cannot update status without source position")
        }

        let sourceFile = URL(fileURLWithPath: startPos.sourceName)
        let backup = backupPath(for: sourceFile)

        try createBackup(source: sourceFile, backup: backup)

        do {
            var lines = try String(contentsOf: sourceFile, encoding: .utf8)
                .components(separatedBy: "\n")

            let lineIndex = startPos.sourceLine - 1
            guard lineIndex >= 0 && lineIndex < lines.count else {
                throw BackendError.commandFailed("Transaction source line out of range")
            }

            let dateLine = lines[lineIndex]
            // Date line format: "2024-01-01 [*|!] [(code)] description [; comment]"
            // Match date, then optional status marker
            let pattern = /^(\d{4}-\d{2}-\d{2})\s+([*!]\s+)?(.*)$/
            guard let match = dateLine.wholeMatch(of: pattern) else {
                throw BackendError.commandFailed("Cannot parse transaction date line")
            }

            let date = String(match.1)
            let rest = String(match.3)
            let statusStr = newStatus == .unmarked ? "" : "\(newStatus.symbol) "

            lines[lineIndex] = "\(date) \(statusStr)\(rest)"

            try lines.joined(separator: "\n").write(to: sourceFile, atomically: true, encoding: .utf8)
            try await validate(mainJournal: mainJournal, sourceFile: sourceFile, backup: backup, validator: validator)
        } catch let error as BackendError {
            throw error
        } catch {
            restoreBackup(source: sourceFile, backup: backup)
            cleanupBackup(backup)
            throw BackendError.commandFailed("Failed to update status: \(error.localizedDescription)")
        }
    }

    // MARK: - Delete

    /// Delete a transaction from the journal using source positions.
    static func delete(
        transaction: Transaction,
        mainJournal: URL,
        validator: any AccountingBackend
    ) async throws {
        guard let startPos = transaction.sourcePosStart, let endPos = transaction.sourcePosEnd else {
            throw BackendError.commandFailed("Cannot delete transaction without source position")
        }

        let sourceFile = URL(fileURLWithPath: startPos.sourceName)
        let backup = backupPath(for: sourceFile)

        try createBackup(source: sourceFile, backup: backup)

        do {
            var lines = try String(contentsOf: sourceFile, encoding: .utf8)
                .components(separatedBy: "\n")

            var startLine = startPos.sourceLine - 1
            let endLine = endPos.sourceLine - 1

            // Remove leading blank line if present
            if startLine > 0 && lines[startLine - 1].trimmingCharacters(in: .whitespaces).isEmpty {
                startLine -= 1
            }

            lines.removeSubrange(startLine..<endLine)
            try lines.joined(separator: "\n").write(to: sourceFile, atomically: true, encoding: .utf8)

            try await validate(mainJournal: mainJournal, sourceFile: sourceFile, backup: backup, validator: validator)
        } catch let error as BackendError {
            throw error
        } catch {
            restoreBackup(source: sourceFile, backup: backup)
            cleanupBackup(backup)
            throw BackendError.commandFailed("Failed to delete transaction: \(error.localizedDescription)")
        }
    }

    // MARK: - Private: Append Helpers

    private static func appendToFile(
        transaction: Transaction,
        targetFile: URL,
        mainJournal: URL,
        validator: any AccountingBackend
    ) async throws {
        let backup = backupPath(for: targetFile)
        try createBackup(source: targetFile, backup: backup)

        do {
            var content = try String(contentsOf: targetFile, encoding: .utf8)
            if !content.isEmpty && !content.hasSuffix("\n\n") {
                content += content.hasSuffix("\n") ? "\n" : "\n\n"
            }
            content += TransactionFormatter.format(transaction) + "\n"
            try content.write(to: targetFile, atomically: true, encoding: .utf8)

            try await validate(mainJournal: mainJournal, sourceFile: targetFile, backup: backup, validator: validator)
        } catch let error as BackendError {
            throw error
        } catch {
            restoreBackup(source: targetFile, backup: backup)
            cleanupBackup(backup)
            throw BackendError.commandFailed("Failed to append transaction: \(error.localizedDescription)")
        }
    }

    private static func appendToNewSubjournal(
        transaction: Transaction,
        targetFile: URL,
        targetName: String,
        mainJournal: URL,
        validator: any AccountingBackend
    ) async throws {
        let mainBackup = backupPath(for: mainJournal)
        try createBackup(source: mainJournal, backup: mainBackup)

        do {
            var mainContent = try String(contentsOf: mainJournal, encoding: .utf8)
            mainContent = insertIncludeSorted(mainContent, newInclude: targetName)
            try mainContent.write(to: mainJournal, atomically: true, encoding: .utf8)

            let txnText = TransactionFormatter.format(transaction) + "\n"
            try txnText.write(to: targetFile, atomically: true, encoding: .utf8)

            try await validate(mainJournal: mainJournal, sourceFile: mainJournal, backup: mainBackup, validator: validator)
        } catch {
            try? FileManager.default.removeItem(at: targetFile)
            throw error
        }
    }

    private static func appendToNewGlobSubjournal(
        transaction: Transaction,
        targetFile: URL,
        mainJournal: URL,
        validator: any AccountingBackend
    ) async throws {
        do {
            try FileManager.default.createDirectory(
                at: targetFile.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let txnText = TransactionFormatter.format(transaction) + "\n"
            try txnText.write(to: targetFile, atomically: true, encoding: .utf8)
            try await validator.validateJournal()
        } catch {
            try? FileManager.default.removeItem(at: targetFile)
            throw BackendError.commandFailed("Validation failed, changes reverted: \(error.localizedDescription)")
        }
    }

    private static func appendToNewGlobYear(
        transaction: Transaction,
        targetFile: URL,
        year: String,
        mainJournal: URL,
        validator: any AccountingBackend
    ) async throws {
        let mainBackup = backupPath(for: mainJournal)
        try createBackup(source: mainJournal, backup: mainBackup)
        let yearDir = mainJournal.deletingLastPathComponent().appendingPathComponent(year)
        let yearDirCreated = !FileManager.default.fileExists(atPath: yearDir.path)

        do {
            var mainContent = try String(contentsOf: mainJournal, encoding: .utf8)
            mainContent = insertGlobIncludeSorted(mainContent, newInclude: "\(year)/*.journal")
            try mainContent.write(to: mainJournal, atomically: true, encoding: .utf8)

            try FileManager.default.createDirectory(at: yearDir, withIntermediateDirectories: true)
            let txnText = TransactionFormatter.format(transaction) + "\n"
            try txnText.write(to: targetFile, atomically: true, encoding: .utf8)

            try await validate(mainJournal: mainJournal, sourceFile: mainJournal, backup: mainBackup, validator: validator)
        } catch {
            try? FileManager.default.removeItem(at: targetFile)
            if yearDirCreated, let contents = try? FileManager.default.contentsOfDirectory(atPath: yearDir.path), contents.isEmpty {
                try? FileManager.default.removeItem(at: yearDir)
            }
            throw error
        }
    }

    // MARK: - Private: Routing Detection

    static func detectRoutingStrategy(_ content: String) -> RoutingStrategy {
        // Check glob first: include YYYY/*.journal
        let globPattern = /^\s*include\s+(\d{4})\/\*\.journal\s*$/
        var globYears: [String] = []
        for line in content.split(separator: "\n") {
            if let match = String(line).firstMatch(of: globPattern) {
                globYears.append(String(match.1))
            }
        }
        if !globYears.isEmpty { return .glob(globYears) }

        // Check flat: include YYYY-MM.journal
        let flatPattern = /^\s*include\s+(\d{4}-\d{2}\.journal)\s*$/
        var flatFiles: [String] = []
        for line in content.split(separator: "\n") {
            if let match = String(line).firstMatch(of: flatPattern) {
                flatFiles.append(String(match.1))
            }
        }
        if !flatFiles.isEmpty { return .flat(flatFiles) }

        return .fallback
    }

    private static func targetSubjournalName(for transaction: Transaction) -> String {
        String(transaction.date.prefix(7)) + ".journal"
    }

    private static func globTargetPath(mainJournal: URL, transaction: Transaction) -> (URL, String) {
        let year = String(transaction.date.prefix(4))
        let month = String(transaction.date.dropFirst(5).prefix(2))
        let target = mainJournal.deletingLastPathComponent()
            .appendingPathComponent(year)
            .appendingPathComponent("\(month).journal")
        return (target, year)
    }

    // MARK: - Private: Include Insertion

    static func insertIncludeSorted(_ content: String, newInclude: String) -> String {
        let newLine = "include \(newInclude)"
        var lines = content.components(separatedBy: "\n")
        let pattern = /^\s*include\s+(\d{4}-\d{2}\.journal)\s*$/

        var datePositions: [(index: Int, filename: String)] = []
        for (i, line) in lines.enumerated() {
            if let match = line.firstMatch(of: pattern) {
                datePositions.append((i, String(match.1)))
            }
        }

        if datePositions.isEmpty {
            return content + (content.hasSuffix("\n") ? "" : "\n") + newLine + "\n"
        }

        var insertIdx = datePositions.last!.index + 1
        for (lineIdx, filename) in datePositions {
            if newInclude < filename {
                insertIdx = lineIdx
                break
            }
        }

        lines.insert(newLine, at: insertIdx)
        return lines.joined(separator: "\n")
    }

    static func insertGlobIncludeSorted(_ content: String, newInclude: String) -> String {
        let newLine = "include \(newInclude)"
        var lines = content.components(separatedBy: "\n")
        let pattern = /^\s*include\s+(\d{4})\/\*\.journal\s*$/
        let newYear = String(newInclude.prefix(4))

        var globPositions: [(index: Int, year: String)] = []
        for (i, line) in lines.enumerated() {
            if let match = line.firstMatch(of: pattern) {
                globPositions.append((i, String(match.1)))
            }
        }

        if globPositions.isEmpty {
            return content + (content.hasSuffix("\n") ? "" : "\n") + newLine + "\n"
        }

        var insertIdx = globPositions.last!.index + 1
        for (lineIdx, year) in globPositions {
            if newYear < year {
                insertIdx = lineIdx
                break
            }
        }

        lines.insert(newLine, at: insertIdx)
        return lines.joined(separator: "\n")
    }

    // MARK: - Private: Backup / Restore

    private static func backupPath(for file: URL) -> URL {
        file.appendingPathExtension("bak")
    }

    private static func createBackup(source: URL, backup: URL) throws {
        try FileManager.default.copyItem(at: source, to: backup)
    }

    private static func restoreBackup(source: URL, backup: URL) {
        try? FileManager.default.removeItem(at: source)
        try? FileManager.default.moveItem(at: backup, to: source)
    }

    private static func cleanupBackup(_ backup: URL) {
        try? FileManager.default.removeItem(at: backup)
    }

    private static func validate(
        mainJournal: URL,
        sourceFile: URL,
        backup: URL,
        validator: any AccountingBackend
    ) async throws {
        do {
            try await validator.validateJournal()
            cleanupBackup(backup)
        } catch {
            restoreBackup(source: sourceFile, backup: backup)
            cleanupBackup(backup)
            throw BackendError.journalValidationFailed("Validation failed, changes reverted: \(error.localizedDescription)")
        }
    }
}
