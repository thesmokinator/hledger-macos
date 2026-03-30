/// Models for financial reports, period summaries, and budgets.

import Foundation

/// Financial summary for a single period (e.g. one month).
struct PeriodSummary: Sendable {
    var income: Decimal
    var expenses: Decimal
    var commodity: String
    var investments: Decimal = 0

    /// Net disposable income (income minus expenses minus investments).
    var net: Decimal {
        income - expenses - investments
    }
}

/// A row in the budget report comparing actual vs budgeted spending.
struct BudgetRow: Identifiable, Sendable {
    let id: UUID
    var account: String
    var actual: Decimal
    var budget: Decimal
    var commodity: String

    init(
        id: UUID = UUID(),
        account: String,
        actual: Decimal,
        budget: Decimal,
        commodity: String
    ) {
        self.id = id
        self.account = account
        self.actual = actual
        self.budget = budget
        self.commodity = commodity
    }

    var remaining: Decimal { budget - actual }

    var usagePct: Double {
        guard budget != 0 else { return 0.0 }
        return NSDecimalNumber(decimal: actual / budget * 100).doubleValue
    }
}

/// A single row in a multi-period financial report.
struct ReportRow: Identifiable, Sendable {
    let id: UUID
    var account: String
    var amounts: [String] = []
    var isSectionHeader: Bool = false
    var isTotal: Bool = false

    init(
        id: UUID = UUID(),
        account: String,
        amounts: [String] = [],
        isSectionHeader: Bool = false,
        isTotal: Bool = false
    ) {
        self.id = id
        self.account = account
        self.amounts = amounts
        self.isSectionHeader = isSectionHeader
        self.isTotal = isTotal
    }
}

/// Parsed output of a multi-period hledger report (IS, BS, CF).
struct ReportData: Sendable {
    var title: String
    var periodHeaders: [String] = []
    var rows: [ReportRow] = []
}

/// Journal statistics from hledger stats.
struct JournalStats: Sendable {
    var transactionCount: Int
    var accountCount: Int
    var commodities: [String] = []
}
