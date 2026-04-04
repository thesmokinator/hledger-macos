/// Builds context from journal data for the AI assistant prompt.
/// Formats accounts, balances, stats, and recent transactions into
/// a compact text representation suitable for the LLM context window.

import Foundation

@MainActor
struct JournalContextBuilder {
    /// Build a system prompt with journal context from the current app state.
    static func buildSystemPrompt(from appState: AppState) -> String {
        var sections: [String] = []

        let today = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()

        sections.append("""
        You are a financial assistant for an hledger plain text accounting journal.
        Today's date is \(today). The currently viewed period is \(appState.periodLabel).

        IMPORTANT RULES:
        - Answer ONLY from the data provided below. Do NOT invent or estimate numbers.
        - If the user asks about a period or data not included below, say "I only have data for \(appState.periodLabel)."
        - Always include the currency/commodity when mentioning amounts.
        - Use plain text in responses. Do not use markdown headers or bold formatting.
        - Be concise.
        """)

        // Journal stats
        if let stats = appState.journalStats {
            sections.append("""
            JOURNAL OVERVIEW:
            Transactions: \(stats.transactionCount), Accounts: \(stats.accountCount), Commodities: \(stats.commodities.joined(separator: ", "))
            """)
        }

        // Period summary with explicit period label
        if let summary = appState.summaryAllTime {
            sections.append("""
            SUMMARY FOR \(appState.periodLabel.uppercased()):
            Income: \(summary.income) \(summary.commodity)
            Expenses: \(summary.expenses) \(summary.commodity)
            Net: \(summary.net) \(summary.commodity)
            """)
        }

        // Expense breakdown
        if !appState.expenseBreakdown.isEmpty {
            var lines = ["EXPENSE BREAKDOWN FOR \(appState.periodLabel.uppercased()):"]
            for (account, amount, commodity) in appState.expenseBreakdown {
                lines.append("\(account): \(amount) \(commodity)")
            }
            sections.append(lines.joined(separator: "\n"))
        }

        // Income breakdown
        if !appState.incomeBreakdown.isEmpty {
            var lines = ["INCOME BREAKDOWN FOR \(appState.periodLabel.uppercased()):"]
            for (account, amount, commodity) in appState.incomeBreakdown {
                lines.append("\(account): \(amount) \(commodity)")
            }
            sections.append(lines.joined(separator: "\n"))
        }

        // Account balances (all-time)
        if !appState.accountBalances.isEmpty {
            var balanceLines = ["ACCOUNT BALANCES (all-time):"]
            for (account, balance) in appState.accountBalances.prefix(100) {
                balanceLines.append("\(account): \(balance)")
            }
            if appState.accountBalances.count > 100 {
                balanceLines.append("... and \(appState.accountBalances.count - 100) more accounts")
            }
            sections.append(balanceLines.joined(separator: "\n"))
        }

        // Assets
        if !appState.assets.isEmpty {
            var lines = ["ASSETS:"]
            for (account, amount, commodity) in appState.assets {
                lines.append("\(account): \(amount) \(commodity)")
            }
            sections.append(lines.joined(separator: "\n"))
        }

        // Liabilities
        if !appState.liabilities.isEmpty {
            var lines = ["LIABILITIES:"]
            for (account, amount, commodity) in appState.liabilities {
                lines.append("\(account): \(amount) \(commodity)")
            }
            sections.append(lines.joined(separator: "\n"))
        }

        // Recent transactions (compact format)
        if !appState.transactions.isEmpty {
            var lines = ["TRANSACTIONS FOR \(appState.periodLabel.uppercased()) (\(appState.transactions.count) total):"]
            for txn in appState.transactions.prefix(50) {
                let status = txn.status == .cleared ? "*" : txn.status == .pending ? "!" : ""
                let postings = txn.postings.map { p in
                    let amt = p.amounts.first.map { "\($0.quantity) \($0.commodity)" } ?? ""
                    return "\(p.account) \(amt)"
                }.joined(separator: " | ")
                lines.append("\(txn.date) \(status) \(txn.description) [\(postings)]")
            }
            if appState.transactions.count > 50 {
                lines.append("... and \(appState.transactions.count - 50) more transactions this period")
            }
            sections.append(lines.joined(separator: "\n"))
        }

        return sections.joined(separator: "\n\n")
    }
}
