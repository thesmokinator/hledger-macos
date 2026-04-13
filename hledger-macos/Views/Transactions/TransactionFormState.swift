/// Observable state and logic for `TransactionFormView`.
///
/// Split out from the view so the form data, prefill, validation, and save
/// flow can be reasoned about (and tested) independently of the SwiftUI
/// body. The view keeps focus state, dismiss, and the FormShellView wiring;
/// everything else lives here. See #92.

import SwiftUI

@MainActor
@Observable
final class TransactionFormState {

    // MARK: - Identity (set at init)

    let editingTransaction: Transaction?
    let isClone: Bool

    // MARK: - Form data

    var dateYear = ""
    var dateMonth = ""
    var dateDay = ""
    var description = ""
    var status: TransactionStatus = .unmarked
    var code = ""
    var comment = ""
    var postingRows: [PostingRow] = []

    // MARK: - Save flow state

    var isSaving = false
    var errorMessage: String?

    // MARK: - Autocomplete data

    var knownAccounts: [String] = []
    var knownDescriptions: [String] = []

    init(editingTransaction: Transaction?, isClone: Bool) {
        self.editingTransaction = editingTransaction
        self.isClone = isClone
    }

    // MARK: - Computed

    var isEditing: Bool { editingTransaction != nil && !isClone }

    var title: String {
        if isClone { return "Clone Transaction" }
        if isEditing { return "Edit Transaction" }
        return "New Transaction"
    }

    var dateString: String {
        "\(dateYear)-\(dateMonth)-\(dateDay)"
    }

    var isDateValid: Bool {
        guard dateYear.count == 4, dateMonth.count == 2, dateDay.count == 2 else { return false }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: dateString) != nil
    }

    // MARK: - Prefill

    func prefill() {
        if let txn = editingTransaction {
            let parts = (isClone ? "" : txn.date).split(separator: "-").map(String.init)
            dateYear = parts.count > 0 ? parts[0] : ""
            dateMonth = parts.count > 1 ? parts[1] : ""
            dateDay = parts.count > 2 ? parts[2] : ""
            description = txn.description
            status = txn.status
            code = txn.code
            comment = txn.comment
            postingRows = txn.postings.map {
                PostingRow(
                    account: $0.account,
                    amount: $0.amounts.first.map { $0.formattedForEditing() } ?? "",
                    comment: $0.comment,
                    balanceAssertion: $0.balanceAssertion
                )
            }
        }

        while postingRows.count < 2 { postingRows.append(PostingRow()) }

        if dateYear.isEmpty && editingTransaction == nil {
            let f = DateFormatter()
            f.dateFormat = "yyyy"
            dateYear = f.string(from: Date())
            f.dateFormat = "MM"
            dateMonth = f.string(from: Date())
            f.dateFormat = "dd"
            dateDay = f.string(from: Date())
        }
    }

    // MARK: - Autocomplete

    func loadAutocompleteData(from backend: (any AccountingBackend)?) async {
        guard let backend else { return }
        knownAccounts = (try? await backend.loadAccounts()) ?? []
        knownDescriptions = (try? await backend.loadDescriptions()) ?? []
    }

    // MARK: - Save

    /// Persist the current form state to the journal.
    ///
    /// - Returns: `true` if the save succeeded — the caller should dismiss
    ///   the form. `false` if it failed; `errorMessage` is set to the failure
    ///   reason and the form should remain visible.
    func save(using appState: AppState) async -> Bool {
        guard let backend = appState.activeBackend else { return false }
        isSaving = true
        errorMessage = nil

        var postings: [Posting] = []
        for row in postingRows where !row.account.isEmpty {
            postings.append(Posting(
                account: row.account,
                amounts: parseAmountString(row.amount, using: appState),
                comment: row.comment,
                balanceAssertion: row.balanceAssertion
            ))
        }

        // hledger accepts transactions with 0 postings.

        let newTransaction = Transaction(
            index: 0,
            date: dateString,
            description: description,
            postings: postings,
            status: status,
            code: code,
            comment: comment
        )

        do {
            if isEditing, let original = editingTransaction {
                try await backend.replaceTransaction(original, with: newTransaction)
            } else {
                try await backend.appendTransaction(newTransaction)
            }
            isSaving = false
            Task { await appState.reloadAfterWrite() }
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }

    private func parseAmountString(_ s: String, using appState: AppState) -> [Amount] {
        guard let amount = appState.parseFormAmount(s) else { return [] }
        return [amount]
    }
}

// MARK: - PostingRow

/// One row in the postings table of a transaction form. Lives next to the
/// state because the state owns `[PostingRow]` and the row IS form data.
struct PostingRow: Identifiable {
    let id = UUID()
    var account: String = ""
    var amount: String = ""
    var comment: String = ""
    var balanceAssertion: String = ""
}
