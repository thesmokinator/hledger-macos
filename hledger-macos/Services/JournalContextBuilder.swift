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
        You are a financial assistant for a personal hledger plain text accounting journal.
        Today is \(today). The user is currently viewing \(appState.periodLabel).

        You have tools to query the journal. ALWAYS use tools to get data before answering.
        Never guess or estimate numbers — call the appropriate tool instead.
        Present the tool results clearly and concisely to the user.
        Always include the currency when mentioning amounts.
        Respond in the same language as the user's question.
        """

        if let stats = appState.journalStats {
            prompt += "\n\nJournal has \(stats.transactionCount) transactions across \(stats.accountCount) accounts."
            if !stats.commodities.isEmpty {
                prompt += " Commodities: \(stats.commodities.joined(separator: ", "))."
            }
        }

        return prompt
    }
}
