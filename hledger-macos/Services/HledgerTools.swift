/// Apple Foundation Models tools that call hledger for real data.
/// Each tool maps to an AccountingBackend method, returning precise results.

import Foundation
import FoundationModels

// MARK: - Tool Arguments

@Generable(description: "A time period for financial queries")
struct PeriodQuery {
    @Guide(description: "Period in YYYY-MM format, e.g. 2026-04 for April 2026")
    var period: String
}

@Generable(description: "A search query for transactions")
struct TransactionQuery {
    @Guide(description: "hledger query: use desc:keyword for description, acct:name for account, amt:>100 for amount filters")
    var query: String
}

// MARK: - Tools

/// Get income and expenses summary for a period.
struct PeriodSummaryTool: Tool {
    let backend: any AccountingBackend

    var name: String { "getPeriodSummary" }
    var description: String { "Get total income, expenses, and net for a given month. Use this when the user asks about income, expenses, or net for a specific period." }

    @concurrent func call(arguments: PeriodQuery) async throws -> String {
        let summary = try await backend.loadPeriodSummary(period: arguments.period)
        return """
        Period: \(arguments.period)
        Income: \(summary.income) \(summary.commodity)
        Expenses: \(summary.expenses) \(summary.commodity)
        Net: \(summary.net) \(summary.commodity)
        """
    }
}

/// Get expense breakdown by account for a period.
struct ExpenseBreakdownTool: Tool {
    let backend: any AccountingBackend

    var name: String { "getExpenseBreakdown" }
    var description: String { "Get expenses broken down by account for a given month. Use this when the user asks about spending categories or top expenses." }

    @concurrent func call(arguments: PeriodQuery) async throws -> String {
        let breakdown = try await backend.loadExpenseBreakdown(period: arguments.period)
        if breakdown.isEmpty { return "No expenses found for \(arguments.period)." }
        let lines = breakdown.map { "\($0.0): \($0.1) \($0.2)" }
        return "Expenses for \(arguments.period):\n" + lines.joined(separator: "\n")
    }
}

/// Get income breakdown by account for a period.
struct IncomeBreakdownTool: Tool {
    let backend: any AccountingBackend

    var name: String { "getIncomeBreakdown" }
    var description: String { "Get income broken down by source account for a given month. Use this when the user asks about income sources." }

    @concurrent func call(arguments: PeriodQuery) async throws -> String {
        let breakdown = try await backend.loadIncomeBreakdown(period: arguments.period)
        if breakdown.isEmpty { return "No income found for \(arguments.period)." }
        let lines = breakdown.map { "\($0.0): \($0.1) \($0.2)" }
        return "Income for \(arguments.period):\n" + lines.joined(separator: "\n")
    }
}

/// Get current account balances.
struct AccountBalancesTool: Tool {
    let backend: any AccountingBackend

    var name: String { "getAccountBalances" }
    var description: String { "Get all account balances (all-time). Use this when the user asks about account balances, net worth, or how much is in a specific account." }

    @concurrent func call(arguments: TransactionQuery) async throws -> String {
        let balances = try await backend.loadAccountBalances()
        if balances.isEmpty { return "No account balances found." }
        let query = arguments.query.lowercased()
        let filtered = query.isEmpty ? balances : balances.filter { $0.0.lowercased().contains(query) }
        if filtered.isEmpty { return "No accounts matching '\(arguments.query)'." }
        let lines = filtered.map { "\($0.0): \($0.1)" }
        return "Account balances:\n" + lines.joined(separator: "\n")
    }
}

/// Get assets breakdown.
struct AssetsBreakdownTool: Tool {
    let backend: any AccountingBackend

    var name: String { "getAssets" }
    var description: String { "Get all asset accounts and their current balances. Use this when the user asks about assets or savings." }

    @concurrent func call(arguments: PeriodQuery) async throws -> String {
        let assets = try await backend.loadAssetsBreakdown()
        if assets.isEmpty { return "No assets found." }
        let lines = assets.map { "\($0.0): \($0.1) \($0.2)" }
        return "Assets:\n" + lines.joined(separator: "\n")
    }
}

/// Get liabilities breakdown.
struct LiabilitiesBreakdownTool: Tool {
    let backend: any AccountingBackend

    var name: String { "getLiabilities" }
    var description: String { "Get all liability accounts (debts, loans, mortgages). Use this when the user asks about debts or liabilities." }

    @concurrent func call(arguments: PeriodQuery) async throws -> String {
        let liabilities = try await backend.loadLiabilitiesBreakdown()
        if liabilities.isEmpty { return "No liabilities found." }
        let lines = liabilities.map { "\($0.0): \($0.1) \($0.2)" }
        return "Liabilities:\n" + lines.joined(separator: "\n")
    }
}

/// Search transactions.
struct TransactionSearchTool: Tool {
    let backend: any AccountingBackend

    var name: String { "searchTransactions" }
    var description: String { "Search transactions by description, account, amount, or date. Use hledger query syntax: desc:keyword, acct:name, date:YYYY-MM, amt:>100. Use this when the user asks about specific transactions or wants to find payments." }

    @concurrent func call(arguments: TransactionQuery) async throws -> String {
        let transactions = try await backend.loadTransactions(query: arguments.query, reversed: true)
        if transactions.isEmpty { return "No transactions found for query '\(arguments.query)'." }
        let lines = transactions.prefix(30).map { txn in
            let amount = txn.postings.first(where: { !$0.amounts.isEmpty })?.amounts.first
            let amtStr = amount.map { "\($0.quantity) \($0.commodity)" } ?? ""
            return "\(txn.date) \(txn.description) \(amtStr)"
        }
        var result = "Found \(transactions.count) transactions:\n" + lines.joined(separator: "\n")
        if transactions.count > 30 {
            result += "\n... and \(transactions.count - 30) more"
        }
        return result
    }
}

// MARK: - Tool Factory

enum HledgerTools {
    /// Create all available tools for a given backend.
    static func all(for backend: any AccountingBackend) -> [any Tool] {
        [
            PeriodSummaryTool(backend: backend),
            ExpenseBreakdownTool(backend: backend),
            IncomeBreakdownTool(backend: backend),
            AccountBalancesTool(backend: backend),
            AssetsBreakdownTool(backend: backend),
            LiabilitiesBreakdownTool(backend: backend),
            TransactionSearchTool(backend: backend),
        ]
    }
}
