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

@Generable(description: "A text query to search transactions")
struct TextQuery {
    @Guide(description: "The search text, e.g. a store name like Lidl, or a description keyword")
    var text: String
}

@Generable(description: "No arguments needed")
struct EmptyQuery {
    @Guide(description: "Ignored, pass any value")
    var unused: String?
}

// MARK: - Tools

/// Get income and expenses summary for a period.
struct PeriodSummaryTool: Tool {
    let backend: any AccountingBackend

    var name: String { "getPeriodSummary" }
    var description: String { "Get total income, total expenses, and net balance for a specific month. Call this when the user asks for a financial overview or balance of a month." }

    @concurrent func call(arguments: PeriodQuery) async throws -> String {
        let summary = try await backend.loadPeriodSummary(period: arguments.period)
        return """
        Period: \(arguments.period)
        Total income: \(summary.income) \(summary.commodity)
        Total expenses: \(summary.expenses) \(summary.commodity)
        Net (income minus expenses): \(summary.net) \(summary.commodity)
        """
    }
}

/// Get expense breakdown by account for a period.
struct ExpenseBreakdownTool: Tool {
    let backend: any AccountingBackend

    var name: String { "getExpenses" }
    var description: String { "Get all EXPENSE categories and how much was spent in each for a given month. Call this when the user asks about spending, costs, expenses, what they spent money on, or top expenses. Do NOT use this for income." }

    @concurrent func call(arguments: PeriodQuery) async throws -> String {
        let breakdown = try await backend.loadExpenseBreakdown(period: arguments.period, preferredCommodity: "")
        if breakdown.isEmpty { return "No expenses found for \(arguments.period)." }
        let lines = breakdown.map { "\($0.0): \($0.1) \($0.2)" }
        let total = breakdown.reduce(Decimal.zero) { $0 + $1.1 }
        let commodity = breakdown.first?.2 ?? ""
        return "Expenses for \(arguments.period):\n" + lines.joined(separator: "\n") + "\nTotal expenses: \(total) \(commodity)"
    }
}

/// Get income breakdown by account for a period.
struct IncomeBreakdownTool: Tool {
    let backend: any AccountingBackend

    var name: String { "getIncome" }
    var description: String { "Get all INCOME sources and how much was earned from each for a given month. Call this ONLY when the user asks about income, salary, earnings, or revenue. Do NOT use this for expenses or spending." }

    @concurrent func call(arguments: PeriodQuery) async throws -> String {
        let breakdown = try await backend.loadIncomeBreakdown(period: arguments.period, preferredCommodity: "")
        if breakdown.isEmpty { return "No income found for \(arguments.period)." }
        let lines = breakdown.map { "\($0.0): \($0.1) \($0.2)" }
        let total = breakdown.reduce(Decimal.zero) { $0 + $1.1 }
        let commodity = breakdown.first?.2 ?? ""
        return "Income for \(arguments.period):\n" + lines.joined(separator: "\n") + "\nTotal income: \(total) \(commodity)"
    }
}

/// Get all account balances.
struct AccountBalancesTool: Tool {
    let backend: any AccountingBackend

    var name: String { "getAccountBalances" }
    var description: String { "Get all account balances. Call this when the user asks about a specific account balance, how much is in their bank account, or their net worth. Returns all accounts with their current balance." }

    @concurrent func call(arguments: EmptyQuery) async throws -> String {
        let balances = try await backend.loadAccountBalances()
        if balances.isEmpty { return "No account balances found." }
        let lines = balances.map { "\($0.0): \($0.1)" }
        return "All account balances:\n" + lines.joined(separator: "\n")
    }
}

/// Get assets breakdown.
struct AssetsBreakdownTool: Tool {
    let backend: any AccountingBackend

    var name: String { "getAssets" }
    var description: String { "Get all asset accounts (bank, cash, investments) with current balances. Call this when the user asks about their assets, savings, patrimony, or wealth." }

    @concurrent func call(arguments: EmptyQuery) async throws -> String {
        let assets = try await backend.loadAssetsBreakdown(preferredCommodity: "")
        if assets.isEmpty { return "No assets found." }
        let lines = assets.map { "\($0.0): \($0.1) \($0.2)" }
        return "Assets:\n" + lines.joined(separator: "\n")
    }
}

/// Get liabilities breakdown.
struct LiabilitiesBreakdownTool: Tool {
    let backend: any AccountingBackend

    var name: String { "getLiabilities" }
    var description: String { "Get all liability accounts (debts, loans, mortgages, credit cards). Call this when the user asks about debts, how much they owe, or liabilities." }

    @concurrent func call(arguments: EmptyQuery) async throws -> String {
        let liabilities = try await backend.loadLiabilitiesBreakdown(preferredCommodity: "")
        if liabilities.isEmpty { return "No liabilities found." }
        let lines = liabilities.map { "\($0.0): \($0.1) \($0.2)" }
        return "Liabilities:\n" + lines.joined(separator: "\n")
    }
}

/// Search transactions by description.
struct TransactionSearchTool: Tool {
    let backend: any AccountingBackend

    var name: String { "searchTransactions" }
    var description: String { "Search for transactions by a keyword (store name, description, etc). Call this when the user wants to find specific transactions or payments. Just pass the search text (e.g. 'Lidl', 'restaurant')." }

    /// Convert user text into an hledger query. Exported for testing.
    static func formatQuery(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains(":") {
            return trimmed
        } else if trimmed.first?.isNumber == true || trimmed.hasPrefix(">") || trimmed.hasPrefix("<") {
            return "amt:\(trimmed)"
        } else {
            return "desc:\(trimmed)"
        }
    }

    @concurrent func call(arguments: TextQuery) async throws -> String {
        let raw = arguments.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = Self.formatQuery(raw)

        let transactions = try await backend.loadTransactions(query: query, reversed: true)
        if transactions.isEmpty { return "No transactions found for '\(raw)'." }
        let lines = transactions.prefix(30).map { txn in
            let amount = txn.postings.first(where: { !$0.amounts.isEmpty })?.amounts.first
            let amtStr = amount.map { "\($0.quantity) \($0.commodity)" } ?? ""
            return "\(txn.date) \(txn.description) \(amtStr)"
        }
        var result = "Found \(transactions.count) transaction(s):\n" + lines.joined(separator: "\n")
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
