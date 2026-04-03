/// Protocol defining the contract between the SwiftUI layer and the accounting CLI.
///
/// This protocol defines the contract between the SwiftUI layer and the
/// accounting CLI. Implement this protocol to add support for a new backend.

import Foundation

/// Errors from backend operations.
enum BackendError: LocalizedError {
    case binaryNotFound(String)
    case commandFailed(String)
    case parseError(String)
    case journalValidationFailed(String)
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let name):
            return "\(name) not found"
        case .commandFailed(let msg):
            return msg
        case .parseError(let msg):
            return "Parse error: \(msg)"
        case .journalValidationFailed(let msg):
            return "Validation failed: \(msg)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        }
    }
}

/// Unified protocol for plain text accounting backends.
protocol AccountingBackend: Sendable {
    /// Path to the CLI binary.
    var binaryPath: String { get }

    /// The journal/ledger file this backend operates on.
    var journalFile: URL { get }

    // MARK: - Validation

    func validateJournal() async throws

    // MARK: - Version

    func version() async throws -> String

    // MARK: - Read: Transactions

    func loadTransactions(query: String?, reversed: Bool) async throws -> [Transaction]
    func loadDescriptions() async throws -> [String]

    // MARK: - Read: Accounts

    func loadAccounts() async throws -> [String]
    func loadAccountBalances() async throws -> [(String, String)]
    func loadAccountTreeBalances() async throws -> [AccountNode]
    func loadCommodities() async throws -> [String]

    // MARK: - Read: Stats & Summaries

    func loadJournalStats() async throws -> JournalStats
    func loadPeriodSummary(period: String?) async throws -> PeriodSummary
    func loadExpenseBreakdown(period: String?) async throws -> [(String, Decimal, String)]
    func loadIncomeBreakdown(period: String?) async throws -> [(String, Decimal, String)]
    func loadLiabilitiesBreakdown() async throws -> [(String, Decimal, String)]
    func loadAssetsBreakdown() async throws -> [(String, Decimal, String)]

    // MARK: - Read: Investments

    func loadInvestmentPositions() async throws -> [(String, Decimal, String)]
    func loadInvestmentCost() async throws -> [String: (Decimal, String)]
    func loadInvestmentMarketValues(pricesFile: URL) async throws -> [String: (Decimal, String)]

    // MARK: - Read: Reports

    func loadReport(type: ReportType, periodBegin: String?, periodEnd: String?, commodity: String?) async throws -> ReportData
    func loadBudgetReport(period: String) async throws -> [BudgetRow]

    // MARK: - Write

    func appendTransaction(_ transaction: Transaction) async throws
    func updateTransactionStatus(_ transaction: Transaction, to newStatus: TransactionStatus) async throws
    func replaceTransaction(_ original: Transaction, with new: Transaction) async throws
    func deleteTransaction(_ transaction: Transaction) async throws
}
