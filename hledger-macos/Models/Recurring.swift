/// Models for recurring transaction rules and budget rules.

import Foundation

/// A single recurring transaction rule stored in recurring.journal.
struct RecurringRule: Identifiable, Sendable {
    let id: UUID
    var ruleId: String
    var periodExpr: String
    var description: String
    var postings: [Posting] = []
    var status: TransactionStatus = .unmarked
    var startDate: String? = nil
    var endDate: String? = nil
    var comment: String = ""
    var code: String = ""

    init(
        id: UUID = UUID(),
        ruleId: String,
        periodExpr: String,
        description: String,
        postings: [Posting] = [],
        status: TransactionStatus = .unmarked,
        startDate: String? = nil,
        endDate: String? = nil,
        comment: String = "",
        code: String = ""
    ) {
        self.id = id
        self.ruleId = ruleId
        self.periodExpr = periodExpr
        self.description = description
        self.postings = postings
        self.status = status
        self.startDate = startDate
        self.endDate = endDate
        self.comment = comment
        self.code = code
    }
}

/// A single budget rule mapping an account to a monthly amount.
struct BudgetRule: Identifiable, Sendable {
    let id: UUID
    var account: String
    var amount: Amount
    var category: String = ""

    init(
        id: UUID = UUID(),
        account: String,
        amount: Amount,
        category: String = ""
    ) {
        self.id = id
        self.account = account
        self.amount = amount
        self.category = category
    }
}
