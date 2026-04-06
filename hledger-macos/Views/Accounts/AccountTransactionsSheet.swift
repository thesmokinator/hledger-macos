/// Sheet showing transactions for a specific account with a configurable time period.

import SwiftUI

/// Identifiable wrapper used to drive the sheet presentation.
struct AccountDrillDown: Identifiable {
    let id = UUID()
    let accountName: String
}

// MARK: - Period

enum DrillDownPeriod: String, CaseIterable, Identifiable {
    case month = "month"
    case threeMonths = "3m"
    case sixMonths = "6m"
    case twelveMonths = "12m"
    case all = "all"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .month: return "This Month"
        case .threeMonths: return "3 Months"
        case .sixMonths: return "6 Months"
        case .twelveMonths: return "12 Months"
        case .all: return "All Time"
        }
    }
}

// MARK: - Sheet

struct AccountTransactionsSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let accountName: String

    @State private var transactions: [Transaction] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedPeriod: DrillDownPeriod = .month

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .frame(minWidth: 640, minHeight: 420)
        .task { await load() }
        .onChange(of: selectedPeriod) { Task { await load() } }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(accountName)
                    .font(.title2.bold())
                if !isLoading {
                    Text("\(transactions.count) transaction\(transactions.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Picker("Period", selection: $selectedPeriod) {
                ForEach(DrillDownPeriod.allCases) { period in
                    Text(period.label).tag(period)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()

            Button("Done") { dismiss() }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            Spacer()
            ProgressView("Loading transactions...")
            Spacer()
        } else if let error = errorMessage {
            Spacer()
            ContentUnavailableView("Error", systemImage: "exclamationmark.triangle",
                description: Text(error))
            Spacer()
        } else if transactions.isEmpty {
            Spacer()
            ContentUnavailableView("No Transactions", systemImage: "doc.text",
                description: Text("No transactions found for \(accountName)."))
            Spacer()
        } else {
            List {
                ForEach(transactions) { transaction in
                    TransactionRowView(transaction: transaction)
                }
            }
            .listStyle(.inset)
        }
    }

    // MARK: - Data Loading

    private func load() async {
        guard let backend = appState.activeBackend else { return }
        isLoading = true
        errorMessage = nil
        do {
            let query = buildQuery()
            transactions = try await backend.loadTransactions(query: query, reversed: true)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func buildQuery() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let today = f.string(from: Date())

        var parts = ["acct:\(accountName)"]

        switch selectedPeriod {
        case .month:
            parts.append("date:\(appState.currentPeriod)")
        case .threeMonths:
            if let start = Calendar.current.date(byAdding: .month, value: -3, to: Date()) {
                parts.append("date:\(f.string(from: start))..\(today)")
            }
        case .sixMonths:
            if let start = Calendar.current.date(byAdding: .month, value: -6, to: Date()) {
                parts.append("date:\(f.string(from: start))..\(today)")
            }
        case .twelveMonths:
            if let start = Calendar.current.date(byAdding: .month, value: -12, to: Date()) {
                parts.append("date:\(f.string(from: start))..\(today)")
            }
        case .all:
            break
        }

        return parts.joined(separator: " ")
    }
}
