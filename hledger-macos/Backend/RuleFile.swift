/// Generic protocol and manager for hledger rule files (budget.journal, recurring.journal).
///
/// `RuleFile` captures what is unique to each file type: its filename on disk,
/// how to parse and format rules, which field acts as the business key, and the
/// error messages to produce when a duplicate or missing key is encountered.
///
/// `RuleFileManager<F>` provides the shared file workflow that was previously
/// duplicated between BudgetManager and RecurringManager:
/// - ensure the file exists and the include directive is present in the main journal
/// - atomic backup → write → validate → rollback-on-failure
/// - add / update / delete wrappers around the write workflow

import Foundation

// MARK: - RuleFile protocol

protocol RuleFile {
    associatedtype Rule
    associatedtype Key: Equatable

    static var filename: String { get }

    /// Parse rules from the raw text content of the rule file.
    static func parseRules(from content: String) -> [Rule]

    /// Serialise rules back to the rule file text content.
    static func formatRules(_ rules: [Rule]) -> String

    /// Extract the business key from a rule (used for duplicate detection and lookup).
    static func key(of rule: Rule) -> Key

    static func duplicateError(_ key: Key) -> BackendError
    static func notFoundError(_ key: Key) -> BackendError
}

// MARK: - RuleFileManager

/// Generic file manager that implements the shared workflow for any `RuleFile`.
enum RuleFileManager<F: RuleFile> {

    // MARK: File path

    static func filePath(for journalFile: URL) -> URL {
        journalFile.deletingLastPathComponent().appendingPathComponent(F.filename)
    }

    // MARK: Ensure file exists

    /// Create the rule file if it is missing and prepend an include directive to
    /// the main journal if one is not already present.
    static func ensureFile(journalFile: URL) throws {
        let file = filePath(for: journalFile)

        if !FileManager.default.fileExists(atPath: file.path) {
            try "".write(to: file, atomically: true, encoding: .utf8)
        }

        var journalText = try String(contentsOf: journalFile, encoding: .utf8)
        let hasInclude = journalText.split(separator: "\n").contains {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("include \(F.filename)")
        }

        if !hasInclude {
            journalText = "include \(F.filename)\n\n" + journalText
            try journalText.write(to: journalFile, atomically: true, encoding: .utf8)
        }
    }

    // MARK: Parse / format

    /// Read and parse rules from a rule file at the given path.
    static func parseRules(at filePath: URL) -> [F.Rule] {
        guard FileManager.default.fileExists(atPath: filePath.path),
              let content = try? String(contentsOf: filePath, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return F.parseRules(from: content)
    }

    /// Serialise rules to text (delegates to the concrete `RuleFile` type).
    static func formatRules(_ rules: [F.Rule]) -> String {
        F.formatRules(rules)
    }

    // MARK: Atomic write with validation

    /// Write rules atomically: backup → write → validate journal → remove backup.
    /// Rolls back to the backup if validation fails.
    static func writeRules(
        _ rules: [F.Rule],
        to filePath: URL,
        journalFile: URL,
        validator: any AccountingBackend
    ) async throws {
        let backup = filePath.appendingPathExtension("bak")
        if FileManager.default.fileExists(atPath: filePath.path) {
            try FileManager.default.copyItem(at: filePath, to: backup)
        }

        do {
            let content = F.formatRules(rules)
            try content.write(to: filePath, atomically: true, encoding: .utf8)
            try await validator.validateJournal()
            try? FileManager.default.removeItem(at: backup)
        } catch {
            if FileManager.default.fileExists(atPath: backup.path) {
                try? FileManager.default.removeItem(at: filePath)
                try? FileManager.default.moveItem(at: backup, to: filePath)
            }
            try? FileManager.default.removeItem(at: backup)
            throw BackendError.journalValidationFailed(
                "\(F.filename) validation failed: \(error.localizedDescription)"
            )
        }
    }

    // MARK: CRUD

    static func addRule(
        _ rule: F.Rule,
        journalFile: URL,
        validator: any AccountingBackend
    ) async throws {
        try ensureFile(journalFile: journalFile)
        let path = filePath(for: journalFile)
        var rules = parseRules(at: path)
        let k = F.key(of: rule)
        if rules.contains(where: { F.key(of: $0) == k }) {
            throw F.duplicateError(k)
        }
        rules.append(rule)
        try await writeRules(rules, to: path, journalFile: journalFile, validator: validator)
    }

    static func updateRule(
        key: F.Key,
        newRule: F.Rule,
        journalFile: URL,
        validator: any AccountingBackend
    ) async throws {
        let path = filePath(for: journalFile)
        var rules = parseRules(at: path)
        guard let index = rules.firstIndex(where: { F.key(of: $0) == key }) else {
            throw F.notFoundError(key)
        }
        rules[index] = newRule
        try await writeRules(rules, to: path, journalFile: journalFile, validator: validator)
    }

    static func deleteRule(
        key: F.Key,
        journalFile: URL,
        validator: any AccountingBackend
    ) async throws {
        let path = filePath(for: journalFile)
        var rules = parseRules(at: path)
        let count = rules.count
        rules.removeAll { F.key(of: $0) == key }
        if rules.count == count {
            throw F.notFoundError(key)
        }
        try await writeRules(rules, to: path, journalFile: journalFile, validator: validator)
    }
}
