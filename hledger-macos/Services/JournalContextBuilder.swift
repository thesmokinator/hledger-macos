/// Builds context from journal data for the AI assistant prompt.
/// Formats accounts, balances, stats, and recent transactions into
/// a compact text representation suitable for the LLM context window.

import Foundation

@MainActor
struct JournalContextBuilder {
    /// Build a system prompt with journal context from the current app state.
    static func buildSystemPrompt(from appState: AppState) -> String {
        var sections: [String] = []

        sections.append("""
        You are a helpful financial assistant for an hledger plain text accounting journal.
        Answer questions based ONLY on the data provided below. Be concise and precise with numbers.
        When mentioning amounts, always include the commodity/currency.
        If you cannot answer from the available data, say so clearly.
        """)

        // Journal stats
        if let stats = appState.journalStats {
            sections.append("""
            ## Journal Overview
            - Transactions: \(stats.transactionCount)
            - Accounts: \(stats.accountCount)
            - Commodities: \(stats.commodities.joined(separator: ", "))
            """)
        }

        // Account balances
        if !appState.accountBalances.isEmpty {
            var balanceLines = ["## Account Balances"]
            for (account, balance) in appState.accountBalances.prefix(100) {
                balanceLines.append("- \(account): \(balance)")
            }
            if appState.accountBalances.count > 100 {
                balanceLines.append("- ... and \(appState.accountBalances.count - 100) more accounts")
            }
            sections.append(balanceLines.joined(separator: "\n"))
        }

        // Period summary
        if let summary = appState.summaryAllTime {
            sections.append("""
            ## Current Period Summary
            - Income: \(summary.income) \(summary.commodity)
            - Expenses: \(summary.expenses) \(summary.commodity)
            - Net: \(summary.net) \(summary.commodity)
            """)
        }

        // Expense breakdown
        if !appState.expenseBreakdown.isEmpty {
            var lines = ["## Expense Breakdown"]
            for (account, amount, commodity) in appState.expenseBreakdown.prefix(30) {
                lines.append("- \(account): \(amount) \(commodity)")
            }
            sections.append(lines.joined(separator: "\n"))
        }

        // Income breakdown
        if !appState.incomeBreakdown.isEmpty {
            var lines = ["## Income Breakdown"]
            for (account, amount, commodity) in appState.incomeBreakdown.prefix(30) {
                lines.append("- \(account): \(amount) \(commodity)")
            }
            sections.append(lines.joined(separator: "\n"))
        }

        // Assets
        if !appState.assets.isEmpty {
            var lines = ["## Assets"]
            for (account, amount, commodity) in appState.assets.prefix(30) {
                lines.append("- \(account): \(amount) \(commodity)")
            }
            sections.append(lines.joined(separator: "\n"))
        }

        // Liabilities
        if !appState.liabilities.isEmpty {
            var lines = ["## Liabilities"]
            for (account, amount, commodity) in appState.liabilities.prefix(30) {
                lines.append("- \(account): \(amount) \(commodity)")
            }
            sections.append(lines.joined(separator: "\n"))
        }

        // Recent transactions (compact format)
        if !appState.transactions.isEmpty {
            var lines = ["## Recent Transactions (current period: \(appState.periodLabel))"]
            for txn in appState.transactions.prefix(50) {
                let status = txn.status == .cleared ? "*" : txn.status == .pending ? "!" : ""
                let postings = txn.postings.map { p in
                    let amt = p.amounts.first.map { "\($0.quantity) \($0.commodity)" } ?? ""
                    return "\(p.account) \(amt)"
                }.joined(separator: " | ")
                lines.append("- \(txn.date) \(status) \(txn.description) [\(postings)]")
            }
            if appState.transactions.count > 50 {
                lines.append("- ... and \(appState.transactions.count - 50) more transactions this period")
            }
            sections.append(lines.joined(separator: "\n"))
        }

        return sections.joined(separator: "\n\n")
    }
}
