/// Sheet for creating, editing, or cloning a transaction.

import SwiftUI

struct TransactionFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let editingTransaction: Transaction?
    let isClone: Bool

    @State private var dateYear = ""
    @State private var dateMonth = ""
    @State private var dateDay = ""
    @State private var description = ""
    @State private var status: TransactionStatus = .unmarked
    @State private var code = ""
    @State private var comment = ""
    @State private var postingRows: [PostingRow] = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var knownAccounts: [String] = []
    @State private var knownDescriptions: [String] = []

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case code, comment
        case postingAccount(Int), postingAmount(Int)
    }

    private var isEditing: Bool { editingTransaction != nil && !isClone }

    private var title: String {
        if isClone { return "Clone Transaction" }
        if isEditing { return "Edit Transaction" }
        return "New Transaction"
    }

    private var dateString: String {
        "\(dateYear)-\(dateMonth)-\(dateDay)"
    }

    private var isDateValid: Bool {
        guard dateYear.count == 4, dateMonth.count == 2, dateDay.count == 2 else { return false }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: dateString) != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Title
                    HStack {
                        Spacer()
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                    }
                    .padding(.top, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.xl)

                    // Fields
                    VStack(spacing: 14) {
                        FormRow("Date:") {
                            DateInputField(year: $dateYear, month: $dateMonth, day: $dateDay)
                        }

                        FormRow("Description:") {
                            AutocompleteField(
                                placeholder: "Transaction description",
                                text: $description,
                                suggestions: knownDescriptions
                            )
                        }

                        FormRow("Status:") {
                            HStack {
                                Picker("", selection: $status) {
                                    Text("Unmarked").tag(TransactionStatus.unmarked)
                                    Text("Pending").tag(TransactionStatus.pending)
                                    Text("Cleared").tag(TransactionStatus.cleared)
                                }
                                .labelsHidden()
                                .fixedSize()
                                Spacer()
                            }
                        }

                        FormRow("Code:") {
                            TextField("Optional transaction code", text: $code)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .code)
                        }

                        FormRow("Comment:") {
                            TextField("Optional comment", text: $comment)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .comment)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xxl)

                    // Postings
                    VStack(alignment: .leading, spacing: 8) {
                        Divider().padding(.vertical, Theme.Spacing.md)

                        Text("Postings")
                            .font(.subheadline.bold())

                        Text("Amount: plain number (50.00), currency prefix (\(appState.config.defaultCommodity)50.00), or commodity with cost (-5 STCK @@ \(appState.config.defaultCommodity)200.00). Leave one amount blank to auto-balance.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, Theme.Spacing.xs)

                        Text("Default commodity: \(appState.config.defaultCommodity)")
                            .font(.caption.italic())
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, Theme.Spacing.sm)

                        ForEach(Array(postingRows.enumerated()), id: \.element.id) { index, _ in
                            PostingRowField(
                                index: index,
                                account: $postingRows[index].account,
                                amount: $postingRows[index].amount,
                                comment: $postingRows[index].comment,
                                suggestions: knownAccounts,
                                showRemove: postingRows.count > 2,
                                onRemove: { postingRows.remove(at: index) }
                            )
                        }

                        Button {
                            postingRows.append(PostingRow())
                        } label: {
                            Label("Add Posting", systemImage: "plus")
                        }
                        .controlSize(.small)
                        .padding(.top, Theme.Spacing.xs)
                    }
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.bottom, Theme.Spacing.lg)
                }
            }

            Divider()

            // Footer
            HStack {
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Save") { Task { await save() } }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isSaving || !isDateValid)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.vertical, Theme.Spacing.md)
        }
        .frame(width: 560, height: 580)
        .task { await loadAutocompleteData() }
        .onAppear { prefill() }
    }

    // MARK: - Prefill

    private func prefill() {
        if let txn = editingTransaction {
            let parts = (isClone ? "" : txn.date).split(separator: "-").map(String.init)
            dateYear = parts.count > 0 ? parts[0] : ""
            dateMonth = parts.count > 1 ? parts[1] : ""
            dateDay = parts.count > 2 ? parts[2] : ""
            description = txn.description
            status = txn.status
            code = txn.code
            comment = txn.comment
            postingRows = txn.postings.map { PostingRow(account: $0.account, amount: $0.amounts.first.map { $0.formatted() } ?? "", comment: $0.comment, balanceAssertion: $0.balanceAssertion) }
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

    private func loadAutocompleteData() async {
        guard let backend = appState.activeBackend else { return }
        knownAccounts = (try? await backend.loadAccounts()) ?? []
        knownDescriptions = (try? await backend.loadDescriptions()) ?? []
    }

    // MARK: - Save

    private func save() async {
        guard let backend = appState.activeBackend else { return }
        isSaving = true
        errorMessage = nil

        var postings: [Posting] = []
        for row in postingRows where !row.account.isEmpty {
            postings.append(Posting(account: row.account, amounts: parseAmountString(row.amount), comment: row.comment, balanceAssertion: row.balanceAssertion))
        }

        // hledger accepts transactions with 0 postings

        let newTransaction = Transaction(
            index: 0, date: dateString, description: description,
            postings: postings, status: status, code: code, comment: comment
        )

        do {
            if isEditing, let original = editingTransaction {
                try await backend.replaceTransaction(original, with: newTransaction)
            } else {
                try await backend.appendTransaction(newTransaction)
            }
            dismiss()
            Task { await appState.reloadAfterWrite() }
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func parseAmountString(_ s: String) -> [Amount] {
        guard let amount = PostingAmountParser.parse(
            s,
            defaultCommodity: appState.config.defaultCommodity
        ) else {
            return []
        }
        return [amount]
    }
}

struct PostingRow: Identifiable {
    let id = UUID()
    var account: String = ""
    var amount: String = ""
    var comment: String = ""
    var balanceAssertion: String = ""
}
