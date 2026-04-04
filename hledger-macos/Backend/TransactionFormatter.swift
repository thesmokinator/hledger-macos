/// Formats Transaction objects into hledger journal text.
///
/// Ported from hledger-textual/formatter.py.

import Foundation

enum TransactionFormatter {
    /// Format a complete transaction as journal text.
    static func format(_ transaction: Transaction) -> String {
        // Header line: date [status] [(code)] description
        var headerParts = [transaction.date]

        if transaction.status != .unmarked {
            headerParts.append(transaction.status.symbol)
        }

        if !transaction.code.isEmpty {
            headerParts.append("(\(transaction.code))")
        }

        headerParts.append(transaction.description)
        var header = headerParts.joined(separator: " ")

        if !transaction.comment.isEmpty {
            header += "  ; \(transaction.comment)"
        }

        // Calculate alignment widths
        let accountWidth = max(
            transaction.postings.map(\.account.count).max() ?? 40,
            40
        )

        let amountWidth = max(
            transaction.postings
                .filter { !$0.amounts.isEmpty }
                .map { $0.amounts.map { $0.formatted() }.joined(separator: ", ").count }
                .max() ?? 12,
            12
        )

        // Format postings
        let postingLines = transaction.postings.map { posting in
            formatPosting(posting, accountWidth: accountWidth, amountWidth: amountWidth)
        }

        return header + "\n" + postingLines.joined(separator: "\n")
    }

    /// Format a single posting line.
    static func formatPosting(
        _ posting: Posting,
        accountWidth: Int = 40,
        amountWidth: Int = 12
    ) -> String {
        var line: String

        if posting.amounts.isEmpty {
            line = "    \(posting.account)"
        } else {
            let amountsStr = posting.amounts.map { $0.formatted() }.joined(separator: ", ")
            let paddedAccount = posting.account.padding(toLength: accountWidth, withPad: " ", startingAt: 0)
            let paddedAmount = amountsStr.leftPadded(toLength: amountWidth)
            line = "    \(paddedAccount)  \(paddedAmount)"
        }

        if !posting.balanceAssertion.isEmpty {
            line += " \(posting.balanceAssertion)"
        }

        if !posting.comment.isEmpty {
            line += "  ; \(posting.comment)"
        }

        return line
    }
}

extension String {
    /// Right-align the string to a given length.
    func leftPadded(toLength length: Int) -> String {
        if count >= length { return self }
        return String(repeating: " ", count: length - count) + self
    }
}
