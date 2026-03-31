/// Shared list row styles for consistent table appearance across the app.

import SwiftUI

/// Standard row for account/amount lists (Accounts, Reports, etc).
struct AccountRow: View {
    let label: String
    let value: String
    var labelFont: Font = .callout
    var labelBold: Bool = false
    var labelColor: Color = .primary
    var valueColor: Color = .secondary

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(labelBold ? labelFont.bold() : labelFont)
                .foregroundStyle(labelColor)
                .lineLimit(1)
            Spacer()
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(valueColor)
        }
        .padding(.vertical, ListMetrics.rowPadding)
    }
}

/// Multi-column row for reports (account + N period amounts).
struct ReportRowView: View {
    let account: String
    let amounts: [String]
    var isSectionHeader: Bool = false
    var isTotal: Bool = false
    let formatAmount: (String) -> String
    let amountColor: (String) -> Color

    var body: some View {
        HStack(spacing: 0) {
            Text(account)
                .font(isSectionHeader || isTotal ? .callout.bold() : .callout)
                .foregroundStyle(isSectionHeader ? Color.accentColor : Color.primary)
                .frame(width: ListMetrics.accountColumnWidth, alignment: .leading)
                .lineLimit(1)

            ForEach(Array(amounts.enumerated()), id: \.offset) { _, amount in
                Text(formatAmount(amount))
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(amountColor(amount))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, isSectionHeader ? ListMetrics.sectionPadding : ListMetrics.rowPadding)
        .listRowBackground(isTotal ? Color.secondary.opacity(0.08) : Color.clear)
    }
}

/// Column header row for reports.
struct ReportHeaderRow: View {
    let accountLabel: String
    let periodHeaders: [String]
    let formatHeader: (String) -> String

    var body: some View {
        HStack(spacing: 0) {
            Text(accountLabel)
                .frame(width: ListMetrics.accountColumnWidth, alignment: .leading)

            ForEach(periodHeaders, id: \.self) { header in
                Text(formatHeader(header))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .listRowSeparator(.visible)
    }
}

/// Shared metrics for list layouts.
enum ListMetrics {
    static let rowPadding: CGFloat = 3
    static let sectionPadding: CGFloat = 6
    static let accountColumnWidth: CGFloat = 200
}
