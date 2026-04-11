import Testing
import Foundation
@testable import hledger_for_Mac

// MARK: - Test Helpers

/// Shared helpers for JournalWriter tests.
///
/// Tests that exercise validation use a real `HledgerBackend` against a temp
/// journal file. The pure-logic tests (insertSorted, detectRoutingStrategy
/// edge cases) do not need hledger.
fileprivate enum JWHelpers {

    struct HledgerNotFound: Error {}

    /// Find the hledger binary or throw to skip the test.
    static func requireHledger() throws -> String {
        guard let path = BinaryDetector.findHledger() else {
            throw HledgerNotFound()
        }
        return path
    }

    /// Create a unique temp directory for a test and return its URL.
    /// Caller is responsible for cleanup (use `defer { try? FileManager.default.removeItem(at: dir) }`).
    static func makeTempDir(name: String = "JournalWriterTests") -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Write a journal file with the given content and return its URL.
    static func writeJournal(_ content: String, in dir: URL, name: String = "main.journal") throws -> URL {
        let url = dir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Build a simple balanced transaction (€-denominated by default).
    static func makeTransaction(
        date: String,
        description: String = "Test",
        amount: Decimal = 50,
        commodity: String = "€",
        debitAccount: String = "expenses:test",
        creditAccount: String = "assets:bank"
    ) -> Transaction {
        Transaction(
            index: 0,
            date: date,
            description: description,
            postings: [
                Posting(
                    account: debitAccount,
                    amounts: [Amount(commodity: commodity, quantity: amount, style: .default)]
                ),
                Posting(account: creditAccount)
            ],
            status: .unmarked
        )
    }

    /// Build a HledgerBackend pointed at the given main journal.
    static func backend(for mainJournal: URL) throws -> HledgerBackend {
        let hledgerPath = try requireHledger()
        return HledgerBackend(binaryPath: hledgerPath, journalFile: mainJournal)
    }
}

// MARK: - Pure logic: insertIncludeSorted

@Suite("JournalWriter.insertIncludeSorted")
struct InsertIncludeSortedTests {

    @Test func appendsWhenNoExistingIncludes() {
        let content = "; just a comment\n2026-01-01 Test\n    expenses:food  €50\n    assets:bank\n"
        let result = JournalWriter.insertIncludeSorted(content, newInclude: "2026-01.journal")
        #expect(result.contains("include 2026-01.journal"))
        // Original content is preserved
        #expect(result.contains("; just a comment"))
    }

    @Test func appendsWhenNoExistingIncludesNoTrailingNewline() {
        let content = "; comment without newline"
        let result = JournalWriter.insertIncludeSorted(content, newInclude: "2026-01.journal")
        #expect(result.contains("; comment without newline\ninclude 2026-01.journal\n"))
    }

    @Test func insertsAtBeginningWhenLexicallyFirst() {
        let content = "include 2026-02.journal\ninclude 2026-03.journal\n"
        let result = JournalWriter.insertIncludeSorted(content, newInclude: "2026-01.journal")
        let includes = result.components(separatedBy: "\n").filter { $0.hasPrefix("include") }
        #expect(includes.count == 3)
        #expect(includes[0] == "include 2026-01.journal")
        #expect(includes[1] == "include 2026-02.journal")
        #expect(includes[2] == "include 2026-03.journal")
    }

    @Test func insertsInMiddleWhenLexicallyMiddle() {
        let content = "include 2026-01.journal\ninclude 2026-03.journal\n"
        let result = JournalWriter.insertIncludeSorted(content, newInclude: "2026-02.journal")
        let includes = result.components(separatedBy: "\n").filter { $0.hasPrefix("include") }
        #expect(includes.count == 3)
        #expect(includes[1] == "include 2026-02.journal")
    }

    @Test func insertsAtEndWhenLexicallyLast() {
        let content = "include 2026-01.journal\ninclude 2026-02.journal\n"
        let result = JournalWriter.insertIncludeSorted(content, newInclude: "2026-03.journal")
        let includes = result.components(separatedBy: "\n").filter { $0.hasPrefix("include") }
        #expect(includes.count == 3)
        #expect(includes[2] == "include 2026-03.journal")
    }

    @Test func crossYearOrdering() {
        // Lexical sort places 2025-12 before 2026-01
        let content = "include 2025-12.journal\ninclude 2026-02.journal\n"
        let result = JournalWriter.insertIncludeSorted(content, newInclude: "2026-01.journal")
        let includes = result.components(separatedBy: "\n").filter { $0.hasPrefix("include") }
        #expect(includes[0] == "include 2025-12.journal")
        #expect(includes[1] == "include 2026-01.journal")
        #expect(includes[2] == "include 2026-02.journal")
    }
}

// MARK: - Pure logic: insertGlobIncludeSorted

@Suite("JournalWriter.insertGlobIncludeSorted")
struct InsertGlobIncludeSortedTests {

    @Test func appendsWhenNoExistingGlobs() {
        let content = "; comment\n"
        let result = JournalWriter.insertGlobIncludeSorted(content, newInclude: "2026/*.journal")
        #expect(result.contains("include 2026/*.journal"))
    }

    @Test func insertsAtBeginningWhenEarlierYear() {
        let content = "include 2025/*.journal\ninclude 2026/*.journal\n"
        let result = JournalWriter.insertGlobIncludeSorted(content, newInclude: "2024/*.journal")
        let includes = result.components(separatedBy: "\n").filter { $0.hasPrefix("include") }
        #expect(includes[0] == "include 2024/*.journal")
        #expect(includes[1] == "include 2025/*.journal")
        #expect(includes[2] == "include 2026/*.journal")
    }

    @Test func insertsAtEndWhenLaterYear() {
        let content = "include 2024/*.journal\ninclude 2025/*.journal\n"
        let result = JournalWriter.insertGlobIncludeSorted(content, newInclude: "2026/*.journal")
        let includes = result.components(separatedBy: "\n").filter { $0.hasPrefix("include") }
        #expect(includes[2] == "include 2026/*.journal")
    }
}

// MARK: - Pure logic: detectRoutingStrategy edge cases

@Suite("JournalWriter.detectRoutingStrategy edge cases")
struct DetectRoutingStrategyEdgeCases {

    @Test func globWinsWhenBothPresent() {
        // When a journal has both glob and flat includes, glob takes priority
        // (it is checked first in detectRoutingStrategy).
        let content = """
        include 2026/*.journal
        include 2025-12.journal
        """
        let strategy = JournalWriter.detectRoutingStrategy(content)
        if case .glob(let years) = strategy {
            #expect(years == ["2026"])
        } else {
            Issue.record("Expected glob strategy when both present, got \(strategy)")
        }
    }

    @Test func emptyContentIsFallback() {
        let strategy = JournalWriter.detectRoutingStrategy("")
        if case .fallback = strategy {} else {
            Issue.record("Expected fallback for empty content")
        }
    }

    @Test func leadingWhitespaceOnIncludeLineRecognized() {
        let content = "    include 2026-01.journal\n"
        let strategy = JournalWriter.detectRoutingStrategy(content)
        if case .flat(let files) = strategy {
            #expect(files == ["2026-01.journal"])
        } else {
            Issue.record("Expected flat strategy with leading whitespace, got \(strategy)")
        }
    }
}

// MARK: - Append: fallback strategy

@Suite("JournalWriter.append (fallback)")
struct AppendFallbackTests {

    @Test func appendToEmptyJournal() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try JWHelpers.writeJournal("", in: dir)
        let backend = try JWHelpers.backend(for: main)
        let txn = JWHelpers.makeTransaction(date: "2026-04-15")

        try await JournalWriter.append(transaction: txn, mainJournal: main, validator: backend)

        let final = try String(contentsOf: main, encoding: .utf8)
        #expect(final.contains("2026-04-15"))
        #expect(final.contains("expenses:test"))
        #expect(final.contains("assets:bank"))
        // Backup should be cleaned up after successful validation
        #expect(!FileManager.default.fileExists(atPath: main.appendingPathExtension("bak").path))
    }

    @Test func appendToJournalWithExistingTransaction() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let initial = """
        2026-04-01 Existing
            expenses:food   €25
            assets:bank
        """
        let main = try JWHelpers.writeJournal(initial, in: dir)
        let backend = try JWHelpers.backend(for: main)
        let txn = JWHelpers.makeTransaction(date: "2026-04-15", description: "New")

        try await JournalWriter.append(transaction: txn, mainJournal: main, validator: backend)

        let final = try String(contentsOf: main, encoding: .utf8)
        #expect(final.contains("Existing"))
        #expect(final.contains("New"))
        // Validate via hledger
        try await backend.validateJournal()
    }

    @Test func appendPreservesBlankLineSeparation() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let initial = "2026-04-01 Existing\n    expenses:food   €25\n    assets:bank\n"
        let main = try JWHelpers.writeJournal(initial, in: dir)
        let backend = try JWHelpers.backend(for: main)
        let txn = JWHelpers.makeTransaction(date: "2026-04-15", description: "New")

        try await JournalWriter.append(transaction: txn, mainJournal: main, validator: backend)

        let final = try String(contentsOf: main, encoding: .utf8)
        // Two transactions must be separated by a blank line for hledger
        #expect(final.contains("\n\n2026-04-15") || final.contains("\n\n2026-04-15".replacingOccurrences(of: "\n\n", with: "\n\n")))
        try await backend.validateJournal()
    }

    @Test func appendToJournalWithoutTrailingNewline() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let initial = "2026-04-01 Existing\n    expenses:food   €25\n    assets:bank"
        let main = try JWHelpers.writeJournal(initial, in: dir)
        let backend = try JWHelpers.backend(for: main)
        let txn = JWHelpers.makeTransaction(date: "2026-04-15", description: "New")

        try await JournalWriter.append(transaction: txn, mainJournal: main, validator: backend)
        try await backend.validateJournal()
    }
}

// MARK: - Append: flat strategy

@Suite("JournalWriter.append (flat)")
struct AppendFlatTests {

    @Test func appendToExistingSubjournal() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try JWHelpers.writeJournal("include 2026-04.journal\n", in: dir)
        // Pre-existing subjournal with one transaction
        _ = try JWHelpers.writeJournal(
            "2026-04-01 Existing\n    expenses:food   €25\n    assets:bank\n",
            in: dir,
            name: "2026-04.journal"
        )

        let backend = try JWHelpers.backend(for: main)
        let txn = JWHelpers.makeTransaction(date: "2026-04-15", description: "New")

        try await JournalWriter.append(transaction: txn, mainJournal: main, validator: backend)

        let subjournal = try String(contentsOf: dir.appendingPathComponent("2026-04.journal"), encoding: .utf8)
        #expect(subjournal.contains("Existing"))
        #expect(subjournal.contains("New"))
        try await backend.validateJournal()
    }

    @Test func appendCreatesNewSubjournalAndUpdatesIncludes() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Main has only the March include — April subjournal does not exist
        let main = try JWHelpers.writeJournal("include 2026-03.journal\n", in: dir)
        _ = try JWHelpers.writeJournal(
            "2026-03-15 March txn\n    expenses:food   €10\n    assets:bank\n",
            in: dir,
            name: "2026-03.journal"
        )

        let backend = try JWHelpers.backend(for: main)
        let txn = JWHelpers.makeTransaction(date: "2026-04-15")

        try await JournalWriter.append(transaction: txn, mainJournal: main, validator: backend)

        // April subjournal must have been created
        let aprilJournal = dir.appendingPathComponent("2026-04.journal")
        #expect(FileManager.default.fileExists(atPath: aprilJournal.path))

        // Main must now have BOTH includes, sorted
        let mainContent = try String(contentsOf: main, encoding: .utf8)
        #expect(mainContent.contains("include 2026-03.journal"))
        #expect(mainContent.contains("include 2026-04.journal"))
        let marchIdx = mainContent.range(of: "include 2026-03.journal")!.lowerBound
        let aprilIdx = mainContent.range(of: "include 2026-04.journal")!.lowerBound
        #expect(marchIdx < aprilIdx)

        try await backend.validateJournal()
    }
}

// MARK: - Append: glob strategy

@Suite("JournalWriter.append (glob)")
struct AppendGlobTests {

    @Test func appendToExistingFileInExistingYear() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try JWHelpers.writeJournal("include 2026/*.journal\n", in: dir)
        let yearDir = dir.appendingPathComponent("2026")
        try FileManager.default.createDirectory(at: yearDir, withIntermediateDirectories: true)
        _ = try JWHelpers.writeJournal(
            "2026-04-01 Existing\n    expenses:food   €25\n    assets:bank\n",
            in: yearDir,
            name: "04.journal"
        )

        let backend = try JWHelpers.backend(for: main)
        let txn = JWHelpers.makeTransaction(date: "2026-04-20", description: "New")

        try await JournalWriter.append(transaction: txn, mainJournal: main, validator: backend)

        let monthFile = try String(contentsOf: yearDir.appendingPathComponent("04.journal"), encoding: .utf8)
        #expect(monthFile.contains("Existing"))
        #expect(monthFile.contains("New"))
        try await backend.validateJournal()
    }

    @Test func appendCreatesNewMonthFileInExistingYear() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try JWHelpers.writeJournal("include 2026/*.journal\n", in: dir)
        let yearDir = dir.appendingPathComponent("2026")
        try FileManager.default.createDirectory(at: yearDir, withIntermediateDirectories: true)
        // Existing month so the year dir is non-empty
        _ = try JWHelpers.writeJournal(
            "2026-03-01 March\n    expenses:food   €10\n    assets:bank\n",
            in: yearDir,
            name: "03.journal"
        )

        let backend = try JWHelpers.backend(for: main)
        let txn = JWHelpers.makeTransaction(date: "2026-04-20")

        try await JournalWriter.append(transaction: txn, mainJournal: main, validator: backend)

        let aprilFile = yearDir.appendingPathComponent("04.journal")
        #expect(FileManager.default.fileExists(atPath: aprilFile.path))
        try await backend.validateJournal()
    }

    @Test func appendCreatesNewYearDirAndGlobInclude() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Main only has 2025 glob — 2026 has nothing
        let main = try JWHelpers.writeJournal("include 2025/*.journal\n", in: dir)
        let yearDir2025 = dir.appendingPathComponent("2025")
        try FileManager.default.createDirectory(at: yearDir2025, withIntermediateDirectories: true)
        _ = try JWHelpers.writeJournal(
            "2025-12-01 Old\n    expenses:food   €10\n    assets:bank\n",
            in: yearDir2025,
            name: "12.journal"
        )

        let backend = try JWHelpers.backend(for: main)
        let txn = JWHelpers.makeTransaction(date: "2026-01-15")

        try await JournalWriter.append(transaction: txn, mainJournal: main, validator: backend)

        // New year directory must exist
        let yearDir2026 = dir.appendingPathComponent("2026")
        #expect(FileManager.default.isReadableFile(atPath: yearDir2026.appendingPathComponent("01.journal").path))

        // Main must contain both glob includes
        let mainContent = try String(contentsOf: main, encoding: .utf8)
        #expect(mainContent.contains("include 2025/*.journal"))
        #expect(mainContent.contains("include 2026/*.journal"))

        try await backend.validateJournal()
    }
}

// MARK: - Replace transaction

@Suite("JournalWriter.replace")
struct ReplaceTests {

    @Test func replaceUpdatesAmountAndDescription() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try JWHelpers.writeJournal("", in: dir)
        let backend = try JWHelpers.backend(for: main)

        // 1. Append an initial transaction
        let original = JWHelpers.makeTransaction(date: "2026-04-15", description: "Original", amount: 25)
        try await JournalWriter.append(transaction: original, mainJournal: main, validator: backend)

        // 2. Read it back to get source positions
        let loaded = try await backend.loadTransactions(query: nil, reversed: false)
        let target = try #require(loaded.first)
        #expect(target.sourcePosStart != nil)
        #expect(target.sourcePosEnd != nil)

        // 3. Replace it
        let updated = JWHelpers.makeTransaction(date: "2026-04-15", description: "Updated", amount: 99)
        try await JournalWriter.replace(original: target, with: updated, mainJournal: main, validator: backend)

        // 4. Verify
        let final = try String(contentsOf: main, encoding: .utf8)
        #expect(final.contains("Updated"))
        #expect(!final.contains("Original"))
        try await backend.validateJournal()
    }

    @Test func replaceFirstOfMultipleTransactions() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try JWHelpers.writeJournal("", in: dir)
        let backend = try JWHelpers.backend(for: main)

        try await JournalWriter.append(
            transaction: JWHelpers.makeTransaction(date: "2026-04-01", description: "First"),
            mainJournal: main, validator: backend
        )
        try await JournalWriter.append(
            transaction: JWHelpers.makeTransaction(date: "2026-04-02", description: "Second"),
            mainJournal: main, validator: backend
        )
        try await JournalWriter.append(
            transaction: JWHelpers.makeTransaction(date: "2026-04-03", description: "Third"),
            mainJournal: main, validator: backend
        )

        let loaded = try await backend.loadTransactions(query: nil, reversed: false)
        #expect(loaded.count == 3)
        let first = loaded.first { $0.description == "First" }!

        let replacement = JWHelpers.makeTransaction(date: "2026-04-01", description: "FirstReplaced")
        try await JournalWriter.replace(original: first, with: replacement, mainJournal: main, validator: backend)

        let after = try await backend.loadTransactions(query: nil, reversed: false)
        #expect(after.contains { $0.description == "FirstReplaced" })
        #expect(after.contains { $0.description == "Second" })
        #expect(after.contains { $0.description == "Third" })
        #expect(!after.contains { $0.description == "First" })
    }

    @Test func replaceLastOfMultipleTransactions() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try JWHelpers.writeJournal("", in: dir)
        let backend = try JWHelpers.backend(for: main)

        try await JournalWriter.append(
            transaction: JWHelpers.makeTransaction(date: "2026-04-01", description: "First"),
            mainJournal: main, validator: backend
        )
        try await JournalWriter.append(
            transaction: JWHelpers.makeTransaction(date: "2026-04-02", description: "Last"),
            mainJournal: main, validator: backend
        )

        let loaded = try await backend.loadTransactions(query: nil, reversed: false)
        let last = loaded.first { $0.description == "Last" }!

        let replacement = JWHelpers.makeTransaction(date: "2026-04-02", description: "LastReplaced")
        try await JournalWriter.replace(original: last, with: replacement, mainJournal: main, validator: backend)

        let after = try await backend.loadTransactions(query: nil, reversed: false)
        #expect(after.contains { $0.description == "LastReplaced" })
        #expect(after.contains { $0.description == "First" })
    }

    @Test func replaceWithoutSourcePositionThrows() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try JWHelpers.writeJournal("", in: dir)
        let backend = try JWHelpers.backend(for: main)

        let txnWithoutPos = JWHelpers.makeTransaction(date: "2026-04-15")
        let replacement = JWHelpers.makeTransaction(date: "2026-04-15", description: "Other")

        await #expect(throws: BackendError.self) {
            try await JournalWriter.replace(
                original: txnWithoutPos,
                with: replacement,
                mainJournal: main,
                validator: backend
            )
        }
    }
}

// MARK: - Delete transaction

@Suite("JournalWriter.delete")
struct DeleteTests {

    @Test func deleteFirstTransaction() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try JWHelpers.writeJournal("", in: dir)
        let backend = try JWHelpers.backend(for: main)

        try await JournalWriter.append(
            transaction: JWHelpers.makeTransaction(date: "2026-04-01", description: "First"),
            mainJournal: main, validator: backend
        )
        try await JournalWriter.append(
            transaction: JWHelpers.makeTransaction(date: "2026-04-02", description: "Second"),
            mainJournal: main, validator: backend
        )

        let loaded = try await backend.loadTransactions(query: nil, reversed: false)
        let first = loaded.first { $0.description == "First" }!
        try await JournalWriter.delete(transaction: first, mainJournal: main, validator: backend)

        let after = try await backend.loadTransactions(query: nil, reversed: false)
        #expect(after.count == 1)
        #expect(after.first?.description == "Second")
    }

    @Test func deleteLastTransaction() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try JWHelpers.writeJournal("", in: dir)
        let backend = try JWHelpers.backend(for: main)

        try await JournalWriter.append(
            transaction: JWHelpers.makeTransaction(date: "2026-04-01", description: "First"),
            mainJournal: main, validator: backend
        )
        try await JournalWriter.append(
            transaction: JWHelpers.makeTransaction(date: "2026-04-02", description: "Last"),
            mainJournal: main, validator: backend
        )

        let loaded = try await backend.loadTransactions(query: nil, reversed: false)
        let last = loaded.first { $0.description == "Last" }!
        try await JournalWriter.delete(transaction: last, mainJournal: main, validator: backend)

        let after = try await backend.loadTransactions(query: nil, reversed: false)
        #expect(after.count == 1)
        #expect(after.first?.description == "First")
    }

    @Test func deleteOnlyTransaction() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try JWHelpers.writeJournal("", in: dir)
        let backend = try JWHelpers.backend(for: main)

        try await JournalWriter.append(
            transaction: JWHelpers.makeTransaction(date: "2026-04-15", description: "Only"),
            mainJournal: main, validator: backend
        )

        let loaded = try await backend.loadTransactions(query: nil, reversed: false)
        try await JournalWriter.delete(transaction: loaded[0], mainJournal: main, validator: backend)

        let after = try await backend.loadTransactions(query: nil, reversed: false)
        #expect(after.isEmpty)
    }

    @Test func deleteWithoutSourcePositionThrows() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try JWHelpers.writeJournal("", in: dir)
        let backend = try JWHelpers.backend(for: main)
        let txnWithoutPos = JWHelpers.makeTransaction(date: "2026-04-15")

        await #expect(throws: BackendError.self) {
            try await JournalWriter.delete(transaction: txnWithoutPos, mainJournal: main, validator: backend)
        }
    }
}

// MARK: - Update status

@Suite("JournalWriter.updateStatus")
struct UpdateStatusTests {

    @Test func unmarkedToCleared() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try JWHelpers.writeJournal("", in: dir)
        let backend = try JWHelpers.backend(for: main)

        try await JournalWriter.append(
            transaction: JWHelpers.makeTransaction(date: "2026-04-15", description: "Test"),
            mainJournal: main, validator: backend
        )

        let loaded = try await backend.loadTransactions(query: nil, reversed: false)
        try await JournalWriter.updateStatus(
            transaction: loaded[0],
            newStatus: .cleared,
            mainJournal: main,
            validator: backend
        )

        let final = try String(contentsOf: main, encoding: .utf8)
        #expect(final.contains("2026-04-15 * Test"))
    }

    @Test func clearedToUnmarked() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let initial = """
        2026-04-15 * Test
            expenses:test    €50
            assets:bank
        """
        let main = try JWHelpers.writeJournal(initial, in: dir)
        let backend = try JWHelpers.backend(for: main)

        let loaded = try await backend.loadTransactions(query: nil, reversed: false)
        try await JournalWriter.updateStatus(
            transaction: loaded[0],
            newStatus: .unmarked,
            mainJournal: main,
            validator: backend
        )

        let final = try String(contentsOf: main, encoding: .utf8)
        #expect(final.contains("2026-04-15 Test"))
        #expect(!final.contains("2026-04-15 * Test"))
    }

    @Test func unmarkedToPending() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try JWHelpers.writeJournal("", in: dir)
        let backend = try JWHelpers.backend(for: main)

        try await JournalWriter.append(
            transaction: JWHelpers.makeTransaction(date: "2026-04-15", description: "Test"),
            mainJournal: main, validator: backend
        )
        let loaded = try await backend.loadTransactions(query: nil, reversed: false)
        try await JournalWriter.updateStatus(
            transaction: loaded[0],
            newStatus: .pending,
            mainJournal: main,
            validator: backend
        )

        let final = try String(contentsOf: main, encoding: .utf8)
        #expect(final.contains("2026-04-15 ! Test"))
    }

    @Test func updateStatusWithoutSourcePositionThrows() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try JWHelpers.writeJournal("", in: dir)
        let backend = try JWHelpers.backend(for: main)
        let txnWithoutPos = JWHelpers.makeTransaction(date: "2026-04-15")

        await #expect(throws: BackendError.self) {
            try await JournalWriter.updateStatus(
                transaction: txnWithoutPos,
                newStatus: .cleared,
                mainJournal: main,
                validator: backend
            )
        }
    }
}

// MARK: - Backup / restore on validation failure

@Suite("JournalWriter.backupRestore")
struct BackupRestoreTests {

    @Test func backupCleanedUpAfterSuccess() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try JWHelpers.writeJournal("", in: dir)
        let backend = try JWHelpers.backend(for: main)
        let txn = JWHelpers.makeTransaction(date: "2026-04-15")

        try await JournalWriter.append(transaction: txn, mainJournal: main, validator: backend)

        let backup = main.appendingPathExtension("bak")
        #expect(!FileManager.default.fileExists(atPath: backup.path))
    }

    @Test func validationFailureRestoresOriginalContent() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let initialContent = """
        2026-04-01 Existing
            expenses:food   €25
            assets:bank
        """
        let main = try JWHelpers.writeJournal(initialContent, in: dir)
        let backend = try JWHelpers.backend(for: main)

        // Create a deliberately broken transaction: postings do not balance.
        // hledger will reject it during validation, triggering backup restore.
        let unbalanced = Transaction(
            index: 0,
            date: "2026-04-15",
            description: "Broken",
            postings: [
                Posting(
                    account: "expenses:test",
                    amounts: [Amount(commodity: "€", quantity: 100, style: .default)]
                ),
                Posting(
                    account: "assets:bank",
                    amounts: [Amount(commodity: "€", quantity: 50, style: .default)]
                )
            ],
            status: .unmarked
        )

        await #expect(throws: BackendError.self) {
            try await JournalWriter.append(transaction: unbalanced, mainJournal: main, validator: backend)
        }

        // Original content must have been restored
        let final = try String(contentsOf: main, encoding: .utf8)
        #expect(final.contains("Existing"))
        #expect(!final.contains("Broken"))
        // Backup file must be cleaned up even on failure
        #expect(!FileManager.default.fileExists(atPath: main.appendingPathExtension("bak").path))
    }

    @Test func validationFailureOnReplaceRestoresOriginal() async throws {
        let dir = JWHelpers.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let main = try JWHelpers.writeJournal("", in: dir)
        let backend = try JWHelpers.backend(for: main)

        // Append a valid transaction first
        try await JournalWriter.append(
            transaction: JWHelpers.makeTransaction(date: "2026-04-15", description: "Valid", amount: 50),
            mainJournal: main, validator: backend
        )

        let loaded = try await backend.loadTransactions(query: nil, reversed: false)
        let target = loaded[0]

        let beforeReplace = try String(contentsOf: main, encoding: .utf8)

        // Try to replace with an unbalanced transaction
        let unbalanced = Transaction(
            index: 0,
            date: "2026-04-15",
            description: "BrokenReplace",
            postings: [
                Posting(account: "expenses:test", amounts: [Amount(commodity: "€", quantity: 100, style: .default)]),
                Posting(account: "assets:bank", amounts: [Amount(commodity: "€", quantity: 50, style: .default)])
            ],
            status: .unmarked
        )

        await #expect(throws: BackendError.self) {
            try await JournalWriter.replace(original: target, with: unbalanced, mainJournal: main, validator: backend)
        }

        // File content must be byte-identical to before the failed replace
        let afterReplace = try String(contentsOf: main, encoding: .utf8)
        #expect(afterReplace == beforeReplace)
        #expect(!FileManager.default.fileExists(atPath: main.appendingPathExtension("bak").path))
    }
}
