/// Models for CSV import wizard and rules file management.

import Foundation

/// CSV separator characters supported by hledger.
enum CsvSeparator: String, CaseIterable, Sendable, Identifiable {
    case comma = ","
    case semicolon = ";"
    case tab = "\t"
    case pipe = "|"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .comma: return "Comma (,)"
        case .semicolon: return "Semicolon (;)"
        case .tab: return "Tab"
        case .pipe: return "Pipe (|)"
        }
    }

    /// The hledger rules file representation.
    var rulesValue: String {
        switch self {
        case .tab: return "TAB"
        default: return rawValue
        }
    }

    /// Init from a hledger rules file value.
    init?(rulesValue: String) {
        switch rulesValue.trimmingCharacters(in: .whitespaces) {
        case ",": self = .comma
        case ";": self = .semicolon
        case "TAB", "\t": self = .tab
        case "|": self = .pipe
        default: return nil
        }
    }
}

/// hledger field names for CSV column mapping.
enum HledgerField: String, CaseIterable, Sendable, Identifiable {
    case date
    case date2
    case description
    case code
    case comment
    case amount
    case amountIn = "amount-in"
    case amountOut = "amount-out"
    case currency
    case status
    case account1
    case account2
    case skip

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .date: return "Date"
        case .date2: return "Date2"
        case .description: return "Description"
        case .code: return "Code"
        case .comment: return "Comment"
        case .amount: return "Amount"
        case .amountIn: return "Amount (in)"
        case .amountOut: return "Amount (out)"
        case .currency: return "Currency"
        case .status: return "Status"
        case .account1: return "Account 1"
        case .account2: return "Account 2"
        case .skip: return "Skip"
        }
    }
}

/// A single column mapping: CSV column index → hledger field.
struct ColumnMapping: Identifiable, Sendable, Hashable {
    let id: UUID
    var csvColumnIndex: Int
    var csvColumnHeader: String
    var sampleValue: String
    var assignedField: HledgerField?

    init(csvColumnIndex: Int, csvColumnHeader: String, sampleValue: String = "", assignedField: HledgerField? = nil) {
        self.id = UUID()
        self.csvColumnIndex = csvColumnIndex
        self.csvColumnHeader = csvColumnHeader
        self.sampleValue = sampleValue
        self.assignedField = assignedField
    }
}

/// A conditional rule: when a pattern matches, assign an account.
struct ConditionalRule: Identifiable, Hashable, Sendable {
    let id: UUID
    var pattern: String
    var account: String
    var comment: String

    init(id: UUID = UUID(), pattern: String, account: String, comment: String = "") {
        self.id = id
        self.pattern = pattern
        self.account = account
        self.comment = comment
    }
}

/// Complete configuration for a CSV rules file.
struct CsvRulesConfig: Sendable {
    var name: String = ""
    var separator: CsvSeparator = .comma
    var skipLines: Int = 1
    var dateFormat: String = "%Y-%m-%d"
    var defaultAccount: String = ""
    var defaultCurrency: String = ""
    var newestFirst: Bool = false
    var columnMappings: [ColumnMapping] = []
    var conditionalRules: [ConditionalRule] = []
}

/// A parsed preview transaction from CSV import.
struct CsvPreviewTransaction: Identifiable, Hashable, Sendable {
    let id: UUID
    var date: String
    var description: String
    var amount: String
    var account1: String
    var account2: String
    var isDuplicate: Bool
    var isSelected: Bool

    init(
        date: String, description: String, amount: String,
        account1: String = "", account2: String = "",
        isDuplicate: Bool = false, isSelected: Bool = true
    ) {
        self.id = UUID()
        self.date = date
        self.description = description
        self.amount = amount
        self.account1 = account1
        self.account2 = account2
        self.isDuplicate = isDuplicate
        self.isSelected = isSelected
    }
}

/// Metadata about a discovered rules file on disk.
struct RulesFileInfo: Identifiable, Hashable, Sendable {
    let id: UUID
    var url: URL
    var name: String
    var account1: String
    var isCompanion: Bool
    var lastModified: Date?

    init(url: URL, name: String = "", account1: String = "", isCompanion: Bool = false, lastModified: Date? = nil) {
        self.id = UUID()
        self.url = url
        self.name = name.isEmpty ? url.deletingPathExtension().lastPathComponent : name
        self.account1 = account1
        self.isCompanion = isCompanion
        self.lastModified = lastModified
    }
}
