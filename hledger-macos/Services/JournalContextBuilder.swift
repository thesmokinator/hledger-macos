/// Builds the system prompt for the AI assistant.
/// With tool calling, the prompt only needs instructions and basic context.
/// Actual financial data is fetched on demand by tools.

import Foundation

@MainActor
struct JournalContextBuilder {
    /// Build a system prompt with minimal context — tools provide the real data.
    static func buildSystemPrompt(from appState: AppState) -> String {
        let today = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()

        var prompt = """
        You are a financial assistant for a personal hledger accounting journal.
        Today is \(today). The current month is \(appState.periodLabel).

        RULES:
        - ALWAYS call a tool to get data. Never guess or make up numbers.
        - When the user asks about spending, costs, or expenses: call getExpenses.
        - When the user asks about income, salary, or earnings: call getIncome.
        - When the user asks for a financial summary or balance: call getPeriodSummary.
        - When the user asks about a bank account or specific account: call getAccountBalances.
        - When the user asks about assets, savings, or patrimony: call getAssets.
        - When the user asks about debts, loans, or liabilities: call getLiabilities.
        - When the user asks to find specific transactions: call searchTransactions.
        - If no month is specified, use the current month: \(appState.currentPeriod).
        - Respond in the same language as the user.
        - Do NOT use markdown formatting like ** or ### in your response. Use plain text only.
        - Present amounts with the currency symbol.
        """

        if let stats = appState.journalStats {
            prompt += "\n\nThe journal has \(stats.transactionCount) transactions across \(stats.accountCount) accounts."
            if !stats.commodities.isEmpty {
                prompt += " Currencies: \(stats.commodities.joined(separator: ", "))."
            }
        }

        return prompt
    }
}
