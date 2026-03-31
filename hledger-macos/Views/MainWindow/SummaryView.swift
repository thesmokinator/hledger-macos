/// Financial summary dashboard — a snapshot of the current month's financial state.
/// No period navigation: shows current month income/expenses + all-time liabilities and investments.

import SwiftUI

struct SummaryView: View {
    @Environment(AppState.self) private var appState

    @State private var periodSummary: PeriodSummary?
    @State private var expenseBreakdown: [(String, Decimal, String)] = []
    @State private var incomeBreakdown: [(String, Decimal, String)] = []
    @State private var liabilities: [(String, Decimal, String)] = []
    @State private var portfolio: [PortfolioRow] = []
    @State private var isFetchingPrices = false
    @State private var isLoading = false

    private var currentMonth: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: Date())
    }

    private var currentMonthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        guard let date = f.date(from: currentMonth) else { return currentMonth }
        let display = DateFormatter()
        display.dateFormat = "MMMM yyyy"
        return display.string(from: date)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Summary cards (always visible)
                summaryCards

                // Investments / Portfolio (first, as net worth snapshot)
                if appState.config.investmentsEnabled && !portfolio.isEmpty {
                    portfolioSection
                }

                // Income & Expenses side by side
                if !expenseBreakdown.isEmpty || !incomeBreakdown.isEmpty {
                    HStack(alignment: .top, spacing: 20) {
                        if !incomeBreakdown.isEmpty {
                            breakdownSection(title: "Income", items: incomeBreakdown, color: .green)
                        }
                        if !expenseBreakdown.isEmpty {
                            breakdownSection(title: "Expenses", items: expenseBreakdown, color: .red)
                        }
                    }
                }

                // Liabilities
                if !liabilities.isEmpty {
                    breakdownSection(title: "Liabilities", items: liabilities, color: .orange)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .navigationTitle("Summary")
        .task { await loadData() }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: 16) {
            SummaryCard(title: "Income", summary: periodSummary, value: \.income, color: .green)
            SummaryCard(title: "Expenses", summary: periodSummary, value: \.expenses, color: .red)
            SummaryCard(
                title: "Net", summary: periodSummary, value: \.net,
                color: (periodSummary?.net ?? 0) >= 0 ? .green : .red,
                subtitle: savingRateText
            )
        }
    }

    private var savingRateText: String? {
        guard let s = periodSummary, s.income > 0 else { return nil }
        let rate = ((s.income - s.expenses) / s.income * 100) as NSDecimalNumber
        return "Saving rate: \(rate.intValue)%"
    }

    // MARK: - Breakdown Section

    private func breakdownSection(title: String, items: [(String, Decimal, String)], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).padding(.bottom, 2)

            let total = items.reduce(Decimal(0)) { $0 + $1.1 }

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let (account, amount, commodity) = item
                let pct = total > 0 ? Double(truncating: (amount / total * 100) as NSDecimalNumber) : 0

                HStack(spacing: 12) {
                    Text(account)
                        .font(.callout).lineLimit(1)
                        .frame(minWidth: 100, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.15)).frame(height: 6)
                            RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.6))
                                .frame(width: max(0, geo.size.width * CGFloat(pct / 100)), height: 6)
                        }
                    }
                    .frame(height: 6)

                    Text(formatAmount(amount, commodity: commodity))
                        .font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary)
                        .frame(minWidth: 80, alignment: .trailing)

                    Text("\(Int(pct))%")
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
        portfolio.contains { $0.marketValue != nil } || !appState.config.priceTickers.isEmpty
    }

    private var portfolioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Investments").font(.headline)
                Spacer()
                if isFetchingPrices {
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
            ForEach(portfolio) { row in
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

            // Hint
            if appState.config.priceTickers.isEmpty && !portfolio.isEmpty {
                Text("Configure price tickers in Settings > Investments to see market values.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
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

    // MARK: - Data Loading

    private func loadData() async {
        guard let backend = appState.activeBackend else { return }
        isLoading = true

        let period = currentMonth

        async let summaryTask = backend.loadPeriodSummary(period: period)
        async let expenseTask = backend.loadExpenseBreakdown(period: period)
        async let incomeTask = backend.loadIncomeBreakdown(period: period)
        async let liabilitiesTask = backend.loadLiabilitiesBreakdown()

        do {
            periodSummary = try await summaryTask
            expenseBreakdown = try await expenseTask
            incomeBreakdown = try await incomeTask
            liabilities = try await liabilitiesTask
        } catch {
            appState.errorMessage = error.localizedDescription
        }

        isLoading = false

        if appState.config.investmentsEnabled {
            await loadInvestments(backend: backend)
        }
    }

    private func loadInvestments(backend: any AccountingBackend) async {
        do {
            let positions = try await backend.loadInvestmentPositions()
            let costs = try await backend.loadInvestmentCost()

            var grouped: [String: (Decimal, Decimal, String)] = [:]
            for (account, qty, commodity) in positions {
                let existing = grouped[commodity] ?? (0, 0, "")
                let cost = costs[account]
                let bookVal = cost?.0 ?? 0
                let bookCom = cost?.1 ?? ""
                grouped[commodity] = (existing.0 + qty, existing.1 + bookVal, bookCom.isEmpty ? existing.2 : bookCom)
            }

            portfolio = grouped.map { commodity, values in
                PortfolioRow(commodity: commodity, quantity: values.0, bookValue: values.1, bookCommodity: values.2)
            }.sorted { $0.commodity < $1.commodity }
        } catch {
            return
        }

        let tickers = appState.config.priceTickers
        guard !tickers.isEmpty else { return }

        isFetchingPrices = true
        if let pricesFile = await PriceService.getPricesFile(pricehistPath: appState.config.pricehistBinaryPath, tickers: tickers) {
            do {
                let marketValues = try await backend.loadInvestmentMarketValues(pricesFile: pricesFile)
                let positions = try await backend.loadInvestmentPositions()

                var commodityMarket: [String: Decimal] = [:]
                for (account, _, commodity) in positions {
                    if let mv = marketValues[account] { commodityMarket[commodity, default: 0] += mv.0 }
                }

                portfolio = portfolio.map { row in
                    var updated = row
                    if let mv = commodityMarket[row.commodity] { updated.marketValue = mv }
                    return updated
                }
            } catch {
                print("Market values: \(error.localizedDescription)")
            }
        }
        isFetchingPrices = false
    }
}

// MARK: - Supporting Types

struct PortfolioRow: Identifiable {
    let id = UUID()
    let commodity: String; let quantity: Decimal; let bookValue: Decimal; let bookCommodity: String
    var marketValue: Decimal?
}
