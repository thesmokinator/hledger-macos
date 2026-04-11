/// Data models for transactions, postings, and amounts.
///
/// Ported from hledger-textual/models.py.

import Foundation

// MARK: - Enums

/// Transaction clearing status.
enum TransactionStatus: String, Codable, CaseIterable, Sendable {
    case unmarked = "Unmarked"
    case pending = "Pending"
    case cleared = "Cleared"

    /// The journal symbol for this status.
    var symbol: String {
        switch self {
        case .cleared: return "*"
        case .pending: return "!"
        case .unmarked: return ""
        }
    }
}

/// Which side of the quantity the commodity symbol appears on.
enum CommoditySide: String, Codable, Sendable {
    case left = "L"
    case right = "R"
}

/// Report type for multi-period financial reports.
enum ReportType: String, Codable, CaseIterable, Sendable {
    case incomeStatement = "is"
    case balanceSheet = "bs"
    case cashFlow = "cf"

    var displayName: String {
        switch self {
        case .incomeStatement: return "Income Statement"
        case .balanceSheet: return "Balance Sheet"
        case .cashFlow: return "Cash Flow"
        }
    }
}

// MARK: - Source Position

/// A position in a source file (for tracking where transactions originate).
struct SourcePosition: Codable, Hashable, Sendable {
    let sourceName: String
    let sourceLine: Int
    let sourceColumn: Int
}

// MARK: - Amount Style

/// Formatting style for displaying an amount.
struct AmountStyle: Codable, Hashable, Sendable {
    var commoditySide: CommoditySide = .left
    var commoditySpaced: Bool = false
    var decimalMark: String = "."
    var digitGroupSeparator: String? = nil
    var digitGroupSizes: [Int] = []
    var precision: Int = 2

    static let `default` = AmountStyle()
}

// MARK: - Amount

/// A monetary amount with commodity, quantity, style, and optional cost annotation.
///
/// The `cost` field holds the cost annotation (`@` or `@@`) already converted
/// to a total cost, so callers do not need to distinguish between per-unit and total cost.
struct Amount: Codable, Hashable, Sendable {
    var commodity: String
    var quantity: Decimal
    var style: AmountStyle = .default
    var cost: CostAmount? = nil

    /// Format the amount as a display string.
    func formatted() -> String {
        let qtyStr = Self.formatDecimal(abs(quantity), style: style)
        let sign = quantity < 0 ? "-" : ""
        let space = style.commoditySpaced ? " " : ""

        var base: String
        switch style.commoditySide {
        case .left:
            base = "\(sign)\(commodity)\(space)\(qtyStr)"
        case .right:
            base = "\(sign)\(qtyStr)\(space)\(commodity)"
        }

        if let cost = cost {
            // Use the cost's OWN style — not self.style — so a multi-currency
            // cost-annotated amount like `-5 XDWD @@ €742,55` formats the cost
            // portion with the € commodity's decimal mark, not the XDWD one.
            // See #129.
            let costDisplay = Self.formatDecimal(abs(cost.quantity), style: cost.style)
            let costSpace = cost.style.commoditySpaced ? " " : ""
            let costStr: String
            switch cost.style.commoditySide {
            case .left:
                costStr = "\(cost.commodity)\(costSpace)\(costDisplay)"
            case .right:
                costStr = "\(costDisplay)\(costSpace)\(cost.commodity)"
            }
            base += " @@ \(costStr)"
        }

        return base
    }

    /// Format for display using system locale (e.g. €1.234,56 in it_IT).
    func displayFormatted() -> String {
        AmountFormatter.format(quantity, commodity: commodity)
    }

    /// Format a decimal value using the supplied `AmountStyle`. Static so the
    /// caller can pass a style that is not necessarily `self.style` — needed
    /// to format a cost annotation that has its own commodity and style.
    private static func formatDecimal(_ value: Decimal, style: AmountStyle) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = style.precision
        formatter.maximumFractionDigits = style.precision
        formatter.decimalSeparator = style.decimalMark

        if let separator = style.digitGroupSeparator, !style.digitGroupSizes.isEmpty {
            formatter.usesGroupingSeparator = true
            formatter.groupingSeparator = separator
            formatter.groupingSize = style.digitGroupSizes.first ?? 3
            if style.digitGroupSizes.count > 1 {
                formatter.secondaryGroupingSize = style.digitGroupSizes[1]
            }
        } else {
            formatter.usesGroupingSeparator = false
            formatter.groupingSeparator = ""
        }

        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}

/// Cost annotation stored separately to avoid recursive `Amount` (Codable limitation).
struct CostAmount: Codable, Hashable, Sendable {
    var commodity: String
    var quantity: Decimal
    var style: AmountStyle = .default
}

// MARK: - Posting

/// A single posting within a transaction.
struct Posting: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var account: String
    var amounts: [Amount] = []
    var comment: String = ""
    var status: TransactionStatus = .unmarked
    var balanceAssertion: String = ""

    init(
        id: UUID = UUID(),
        account: String,
        amounts: [Amount] = [],
        comment: String = "",
        status: TransactionStatus = .unmarked,
        balanceAssertion: String = ""
    ) {
        self.id = id
        self.account = account
        self.amounts = amounts
        self.comment = comment
        self.status = status
        self.balanceAssertion = balanceAssertion
    }
}

// MARK: - Transaction

/// A complete journal transaction.
struct Transaction: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var index: Int
    var date: String
    var description: String
    var postings: [Posting] = []
    var status: TransactionStatus = .unmarked
    var code: String = ""
    var comment: String = ""
    var date2: String? = nil
    var sourcePosStart: SourcePosition? = nil
    var sourcePosEnd: SourcePosition? = nil
    var tags: [String] = []

    init(
        id: UUID = UUID(),
        index: Int,
        date: String,
        description: String,
        postings: [Posting] = [],
        status: TransactionStatus = .unmarked,
        code: String = "",
        comment: String = "",
        date2: String? = nil,
        sourcePosStart: SourcePosition? = nil,
        sourcePosEnd: SourcePosition? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.index = index
        self.date = date
        self.description = description
        self.postings = postings
        self.status = status
        self.code = code
        self.comment = comment
        self.date2 = date2
        self.sourcePosStart = sourcePosStart
        self.sourcePosEnd = sourcePosEnd
        self.tags = tags
    }

    /// Returns "I" for income, "E" for expense, "-" for mixed/transfer.
    var typeIndicator: String {
        var hasIncome = false
        var hasExpense = false
        for posting in postings {
            let top = posting.account.split(separator: ":").first?.lowercased() ?? ""
            if ["income", "revenues", "revenue"].contains(top) {
                hasIncome = true
            } else if ["expenses", "expense"].contains(top) {
                hasExpense = true
            }
        }
        if hasIncome && !hasExpense { return "I" }
        if hasExpense && !hasIncome { return "E" }
        return "-"
    }

    /// Sum of positive amounts for display, including cost annotations.
    var totalAmount: String {
        var positiveAmounts: [String: Decimal] = [:]
        var styles: [String: AmountStyle] = [:]

        for posting in postings {
            for amount in posting.amounts {
                if amount.quantity > 0 {
                    let key = amount.commodity
                    positiveAmounts[key, default: 0] += amount.quantity
                    if styles[key] == nil { styles[key] = amount.style }

                    if let cost = amount.cost {
                        let ck = cost.commodity
                        positiveAmounts[ck, default: 0] += abs(cost.quantity)
                        if styles[ck] == nil { styles[ck] = cost.style }
                    }
                }
            }
        }

        if positiveAmounts.isEmpty { return "" }

        let parts = positiveAmounts.map { commodity, qty in
            return AmountFormatter.format(qty, commodity: commodity)
        }
        return parts.joined(separator: ", ")
    }
}
