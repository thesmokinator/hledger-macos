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
    @State private var isPrefilling = true
    @State private var knownAccounts: [String] = []

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case year, month, day, description, code, comment
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
                    .padding(.top, 20)
                    .padding(.bottom, 20)

                    // Fields
                    VStack(spacing: 14) {
                        // Date with structured input
                        formRow("Date:") {
                            HStack(spacing: 4) {
                                TextField("YYYY", text: $dateYear)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .focused($focusedField, equals: .year)
                                    .onChange(of: dateYear) { guard !isPrefilling else { return }; filterDigits(&dateYear, max: 4) { focusedField = .month } }

                                Text("-").foregroundStyle(.secondary)

                                TextField("MM", text: $dateMonth)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 40)
                                    .focused($focusedField, equals: .month)
                                    .onChange(of: dateMonth) { guard !isPrefilling else { return }; filterDigits(&dateMonth, max: 2) { focusedField = .day } }

                                Text("-").foregroundStyle(.secondary)

                                TextField("DD", text: $dateDay)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 40)
                                    .focused($focusedField, equals: .day)
                                    .onChange(of: dateDay) { guard !isPrefilling else { return }; filterDigits(&dateDay, max: 2) { focusedField = .description } }

                                if !dateYear.isEmpty || !dateMonth.isEmpty || !dateDay.isEmpty {
                                    Image(systemName: isDateValid ? "checkmark.circle" : "xmark.circle")
                                        .foregroundStyle(isDateValid ? .green : .red)
                                        .font(.caption)
                                }

                                Spacer()
                            }
                        }

                        formRow("Description:") {
                            TextField("Transaction description", text: $description)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .description)
                        }

                        formRow("Status:") {
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

                        formRow("Code:") {
                            TextField("Optional transaction code", text: $code)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .code)
                        }

                        formRow("Comment:") {
                            TextEditor(text: $comment)
                                .font(.body)
                                .frame(height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(.quaternary, lineWidth: 1)
                                )
                                .focused($focusedField, equals: .comment)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Postings
                    VStack(alignment: .leading, spacing: 8) {
                        Divider().padding(.vertical, 12)

                        Text("Postings")
                            .font(.subheadline.bold())

                        Text("Amount: plain number (50.00), currency prefix (\(appState.config.defaultCommodity)50.00), or commodity with cost (-5 STCK @@ \(appState.config.defaultCommodity)200.00). Leave one amount blank to auto-balance.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 4)

                        Text("Default commodity: \(appState.config.defaultCommodity)")
                            .font(.caption.italic())
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, 8)

                        ForEach(Array(postingRows.enumerated()), id: \.element.id) { index, _ in
                            HStack(spacing: 8) {
                                Text("#\(index + 1):")
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30, alignment: .trailing)

                                AutocompleteField(
                                    placeholder: "e.g. expenses:food",
                                    text: $postingRows[index].account,
                                    suggestions: knownAccounts
                                )

                                TextField("0.00", text: $postingRows[index].amount)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 130)
                                    .focused($focusedField, equals: .postingAmount(index))

                                if postingRows.count > 2 {
                                    Button {
                                        postingRows.remove(at: index)
                                    } label: {
                                        Image(systemName: "minus.circle").foregroundStyle(.red)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }

                        Button {
                            postingRows.append(PostingRow())
                        } label: {
                            Label("Add Posting", systemImage: "plus")
                        }
                        .controlSize(.small)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
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
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .frame(width: 560, height: 580)
        .task { await loadAutocompleteData() }
        .onAppear {
            prefill()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isPrefilling = false
                focusedField = .year
            }
        }
    }

    // MARK: - Form Row

    private func formRow<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
                .padding(.top, 6)
            content()
        }
    }

    // MARK: - Date Filtering

    private func filterDigits(_ value: inout String, max: Int, advance: (() -> Void)? = nil) {
        value = String(value.filter(\.isNumber).prefix(max))
        if value.count == max { advance?() }
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
            postingRows = txn.postings.map { PostingRow(account: $0.account, amount: $0.amounts.first.map { $0.formatted() } ?? "") }
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
    }

    // MARK: - Save

    private func save() async {
        guard let backend = appState.activeBackend else { return }
        isSaving = true
        errorMessage = nil

        var postings: [Posting] = []
        for row in postingRows where !row.account.isEmpty {
            postings.append(Posting(account: row.account, amounts: parseAmountString(row.amount)))
        }

        guard postings.count >= 2 else {
            errorMessage = "At least 2 postings required"
            isSaving = false
            return
        }

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
            await appState.loadTransactions()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func parseAmountString(_ s: String) -> [Amount] {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let (qty, commodity) = AmountParser.parse(trimmed)
        if qty == 0 && commodity.isEmpty { return [] }
        let com = commodity.isEmpty ? appState.config.defaultCommodity : commodity
        let side: CommoditySide = com.first?.isLetter == true && com.count > 1 ? .right : .left
        return [Amount(commodity: com, quantity: qty, style: AmountStyle(commoditySide: side, precision: 2))]
    }
}

struct PostingRow: Identifiable {
    let id = UUID()
    var account: String = ""
    var amount: String = ""
}
