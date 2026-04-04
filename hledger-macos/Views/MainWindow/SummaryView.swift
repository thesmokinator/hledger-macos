/// Financial summary dashboard — a snapshot of the current month's financial state.
/// No period navigation: shows current month income/expenses + all-time liabilities and investments.

import SwiftUI

struct SummaryView: View {
    @Environment(AppState.self) private var appState

    @State private var portfolioSortAscending = true
    @State private var breakdownSortByAmount = true
    @State private var summaryPeriod = "month"

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Summary cards (always visible)
                summaryCards

                // Investments / Portfolio (first, as net worth snapshot)
                if appState.config.investmentsEnabled && !appState.portfolio.isEmpty {
                    portfolioSection
                }

                // Income & Expenses side by side (always visible)
                HStack(alignment: .top, spacing: 20) {
                    breakdownSection(title: "Income", items: appState.incomeBreakdown, color: .green)
                    breakdownSection(title: "Expenses", items: appState.expenseBreakdown, color: .red)
                }

                // Assets & Liabilities side by side (always visible)
                HStack(alignment: .top, spacing: 20) {
                    breakdownSection(title: "Assets", items: appState.assets, color: .blue)
                    breakdownSection(title: "Liabilities", items: appState.liabilities, color: .orange)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("Summary")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { Task { await appState.reload() } } label: {
                    Label("Reload", systemImage: "arrow.triangle.2.circlepath")
                }

                Picker("Period", selection: $summaryPeriod) {
                    Text("Current month").tag("month")
                    Text("Last month").tag("lastmonth")
                    Text("3 months").tag("3m")
                    Text("6 months").tag("6m")
                    Text("12 months").tag("12m")
                    Text("Year to date").tag("ytd")
                }
            }
        }
        .onAppear {
            portfolioSortAscending = appState.config.portfolioSortMode == "asc"
            summaryPeriod = appState.config.summaryPeriod
        }
        .onChange(of: portfolioSortAscending) { appState.config.portfolioSortMode = portfolioSortAscending ? "asc" : "desc" }
        .onChange(of: summaryPeriod) {
            appState.config.summaryPeriod = summaryPeriod
            Task { await appState.loadSummary() }
        }
        .task { await appState.loadSummary() }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: 16) {
            SummaryCard(title: "Income", summary: appState.summaryAllTime, value: \.income, color: .green)
            SummaryCard(title: "Expenses", summary: appState.summaryAllTime, value: \.expenses, color: .red)
            SummaryCard(
                title: "Net", summary: appState.summaryAllTime, value: \.net,
                color: (appState.summaryAllTime?.net ?? 0) >= 0 ? .green : .red,
                subtitle: SummaryCard.netSubtitle(for: appState.summaryAllTime)
            )
        }
    }

    private var sortedPortfolio: [PortfolioRow] {
        appState.portfolio.sorted {
            portfolioSortAscending ? $0.commodity < $1.commodity : $0.commodity > $1.commodity
        }
    }

    // MARK: - Breakdown Section

    private func breakdownSection(title: String, items: [(String, Decimal, String)], color: Color) -> some View {
        let sortedItems = breakdownSortByAmount
            ? items.sorted { $0.1 > $1.1 }
            : items.sorted { $0.0 < $1.0 }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                SortToggleButton(
                    ascending: $breakdownSortByAmount,
                    modeA: .byAmount,
                    modeB: .byName
                )
            }
            .padding(.bottom, 2)

            if items.isEmpty {
                Text("No data for this period")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }

            let total = items.reduce(Decimal(0)) { $0 + $1.1 }
            let maxAmount = items.map(\.1).max() ?? 0

            ForEach(Array(sortedItems.enumerated()), id: \.offset) { _, item in
                let (account, amount, commodity) = item
                let pct = total > 0 ? Double(truncating: (amount / total * 100) as NSDecimalNumber) : 0
                let barRatio = maxAmount > 0 ? Double(truncating: (amount / maxAmount) as NSDecimalNumber) : 0

                HStack(spacing: 12) {
                    Text(account)
                        .font(.callout).lineLimit(1)
                        .frame(minWidth: 100, alignment: .leading)

                    BreakdownBar(ratio: barRatio, color: color, mode: appState.config.barChartMode)

                    Text(formatAmount(amount, commodity: commodity))
                        .font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary)
                        .frame(minWidth: 80, alignment: .trailing)

                    Text((pct / 100).formatted(.percent.precision(.fractionLength(0))))
                        .font(.caption).foregroundStyle(.tertiary)
                        .frame(width: 36, alignment: .trailing)
                }
                .frame(height: 20)
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Portfolio Section

    private var showMarketColumns: Bool {
        appState.portfolio.contains { $0.marketValue != nil } || !appState.config.priceTickers.isEmpty
    }

    private var portfolioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Investments").font(.headline)

                SortToggleButton(ascending: $portfolioSortAscending)

                Spacer()
                if appState.isFetchingPrices {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.small)
                        Text("Fetching prices...").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.bottom, 2)

            // Header
            portfolioRow(
                asset: Text("Asset"),
                qty: Text("Qty"),
                book: Text("Book Value"),
                market: showMarketColumns ? Text("Market Value") : nil,
                gain: showMarketColumns ? Text("Gain/Loss") : nil
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)

            // Rows
            ForEach(sortedPortfolio) { row in
                portfolioRow(
                    asset: Text(row.commodity).font(.callout.weight(.medium)),
                    qty: Text(formatQty(row.quantity)).font(.system(.callout, design: .monospaced)),
                    book: Text(formatAmount(row.bookValue, commodity: row.bookCommodity))
                        .font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary),
                    market: showMarketColumns ? marketValueText(row) : nil,
                    gain: showMarketColumns ? gainLossText(row) : nil
                )
                .frame(height: 24)
            }

            // Hints
            if appState.config.priceTickers.isEmpty && !appState.portfolio.isEmpty {
                Text("Configure price tickers in Settings > Investments to see market values.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            } else if showMarketColumns {
                Text("Market data provided by pricehist via Yahoo Finance. Prices may be delayed.")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Portfolio Helpers

    private func portfolioRow(asset: Text, qty: Text, book: Text, market: Text?, gain: Text?) -> some View {
        HStack(spacing: 0) {
            asset.frame(maxWidth: .infinity, alignment: .leading)
            qty.frame(width: 60, alignment: .trailing)
            book.frame(width: 120, alignment: .trailing)
            if let market {
                market.frame(width: 120, alignment: .trailing)
            }
            if let gain {
                gain.frame(width: 120, alignment: .trailing)
            }
        }
    }

    private func marketValueText(_ row: PortfolioRow) -> Text {
        guard let market = row.marketValue else { return Text("—").foregroundStyle(.tertiary) }
        return Text(formatAmount(market, commodity: row.bookCommodity))
            .font(.system(.callout, design: .monospaced))
            .foregroundStyle(market > row.bookValue ? .green : market < row.bookValue ? .red : .primary)
    }

    private func gainLossText(_ row: PortfolioRow) -> Text {
        guard let market = row.marketValue else { return Text("—").foregroundStyle(.tertiary) }
        let gain = market - row.bookValue
        return Text(formatAmount(gain, commodity: row.bookCommodity))
            .font(.system(.callout, design: .monospaced))
            .foregroundStyle(gain >= 0 ? .green : .red)
    }

    // MARK: - Helpers

    private func formatAmount(_ amount: Decimal, commodity: String) -> String {
        AmountFormatter.format(amount, commodity: commodity)
    }

    private func formatQty(_ qty: Decimal) -> String {
        AmountFormatter.formatQuantity(qty)
    }

}
