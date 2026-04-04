/// Reusable components for breakdown sections in Summary.
/// BreakdownRow renders a full row (label + bar + amount) in dynamic or fixed mode.
/// BreakdownBar renders the proportional colored bar.

import SwiftUI

/// A single row in a breakdown section.
/// Dynamic: label (natural width), bar (proportional), amount, percentage.
/// Fixed: label (160px), bar (proportional), amount (100px). No percentage.
struct BreakdownRow: View {
    let account: String
    let amount: String
    let percentage: Double
    let barRatio: Double
    let color: Color
    let mode: String
    var isMultiCurrency: Bool = false

    @State private var showingMultiCurrencyInfo = false

    private var isFixed: Bool { mode == "fixed" }

    var body: some View {
        HStack(spacing: 12) {
            if isFixed {
                accountLabel
                    .frame(width: 160, alignment: .leading)

                BreakdownBar(ratio: barRatio, color: color)

                Text(amount)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 100, alignment: .trailing)
            } else {
                accountLabel

                BreakdownBar(ratio: barRatio, color: color)

                Text(amount)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 80, alignment: .trailing)

                Text((percentage / 100).formatted(.percent.precision(.fractionLength(0))))
                    .font(.caption).foregroundStyle(.tertiary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .frame(height: 20)
    }

    private var accountLabel: some View {
        HStack(spacing: 4) {
            Text(account)
                .font(.callout).lineLimit(1)
            if isMultiCurrency {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .onTapGesture { showingMultiCurrencyInfo.toggle() }
                    .popover(isPresented: $showingMultiCurrencyInfo) {
                        Text("This account has balances in multiple currencies. Only the default currency is shown here. See Accounts for full details.")
                            .font(.callout)
                            .padding(12)
                            .frame(width: 280)
                    }
            }
        }
    }
}

/// Proportional colored bar.
struct BreakdownBar: View {
    let ratio: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.15))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.6))
                    .frame(width: max(0, geo.size.width * CGFloat(ratio)), height: 6)
            }
        }
        .frame(height: 6)
    }
}
