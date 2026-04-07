/// Reusable summary card for displaying Income, Expenses, Net values.
/// Shows a spinner while loading, formatted amount when data is available.

import SwiftUI

struct SummaryCard: View {
    let title: String
    let summary: PeriodSummary?
    let value: KeyPath<PeriodSummary, Decimal>
    let color: Color
    var subtitle: String? = nil

    /// Compute the Net card subtitle from a PeriodSummary.
    static func netSubtitle(for summary: PeriodSummary?) -> String? {
        guard let s = summary, s.income > 0 else { return nil }
        let rate = NSDecimalNumber(decimal: (s.income - s.expenses) / s.income).doubleValue
        var text = "Saving rate: \(rate.formatted(.percent.precision(.fractionLength(0))))"
        if s.investments > 0 {
            text += " · Invested: \(AmountFormatter.format(s.investments, commodity: s.commodity))"
        }
        return text
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.body)
                .foregroundStyle(.secondary)

            Group {
                if let summary {
                    Text(AmountFormatter.format(summary[keyPath: value], commodity: summary.commodity))
                        .foregroundStyle(color)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .frame(height: 34)

            Text(subtitle ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}
