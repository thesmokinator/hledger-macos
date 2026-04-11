/// Central observable state for the application.

import SwiftUI

/// Sidebar navigation sections.
enum NavigationSection: String, CaseIterable, Identifiable {
    case summary
    case transactions
    case recurring
    case budget
    case reports
    case accounts

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var systemImage: String {
        switch self {
        case .summary: return "chart.pie"
        case .transactions: return "list.bullet.rectangle"
        case .recurring: return "repeat"
        case .budget: return "chart.bar"
        case .reports: return "doc.text.magnifyingglass"
        case .accounts: return "building.columns"
        }
    }

    var shortcutNumber: Int {
        (Self.allCases.firstIndex(of: self) ?? 0) + 1
    }
}

@Observable
@MainActor
final class AppState {
    // MARK: - Dependencies (injected for testability)

    private let binaryDetector: BinaryDetecting
    private let journalResolver: JournalResolving

    // MARK: - Initialization

    var isInitialized = false
    var isChecking = true
    var detectionResult: BinaryDetectionResult?

    // MARK: - Config & Backend

    var config = AppConfig()
    var activeBackend: (any AccountingBackend)?
    private(set) var dataVersion = UUID()

    init() {
        self.binaryDetector = LiveBinaryDetector()
        self.journalResolver = LiveJournalResolver()
    }

    init(binaryDetector: BinaryDetecting, journalResolver: JournalResolving) {
        self.binaryDetector = binaryDetector
        self.journalResolver = journalResolver
    }

    // MARK: - Navigation

    var selectedSection: NavigationSection = .summary

    // MARK: - Data

    var transactions: [Transaction] = []
    var accounts: [String] = []
    var accountBalances: [(String, String)] = []
    var journalStats: JournalStats?
    private(set) var commodityStyles: [String: AmountStyle] = [:]

    // MARK: - Summary Data (cached)

    var summaryAllTime: PeriodSummary?
    var summaryCurrentMonth: PeriodSummary?
    var expenseBreakdown: [(String, Decimal, String)] = []
    var incomeBreakdown: [(String, Decimal, String)] = []
    var liabilities: [(String, Decimal, String)] = []
    var assets: [(String, Decimal, String)] = []
    var portfolio: [PortfolioRow] = []
    var isFetchingPrices = false
    /// Ticker symbols for which no price data could be fetched (e.g. unknown symbol, network error).
    var failedPriceTickers: Set<String> = []
    var multiCurrencyAccounts: Set<String> = []

    // MARK: - UI State

    var isLoading = false
    var errorMessage: String?
    var searchQuery = ""
    var showingNewTransaction = false
    var showingNewBudgetRule = false
    var showingNewRecurringRule = false
    var showingRulesManager = false

    // MARK: - Period Navigation

    var currentPeriod: String = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }()

    // MARK: - Actions

    /// Initialize the app: detect hledger and set up backend.
    func initialize() async {
        isChecking = true

        // Apply configured default section
        if let section = NavigationSection(rawValue: config.defaultSection) {
            selectedSection = section
        }

        let ready = detectAndSetup()
        isChecking = false

        if ready {
            await reload()
        }
    }

    /// Re-scan for hledger (used from onboarding and settings).
    func rescan() async {
        detectAndSetup()
    }

    /// Detect hledger binary, resolve journal, and set up backend.
    /// Sets `isInitialized` only when both binary and journal are available.
    @discardableResult
    func detectAndSetup() -> Bool {
        let result = binaryDetector.detect(customHledgerPath: config.hledgerBinaryPath)
        detectionResult = result

        guard result.isFound else {
            isInitialized = false
            return false
        }

        setupBackend()
        isInitialized = activeBackend != nil
        return isInitialized
    }

    /// Set up the hledger backend.
    func setupBackend() {
        let journalURL = journalResolver.resolve(
            configuredPath: config.journalFilePath,
            shellDetectedPath: detectionResult?.detectedJournalPath
        )

        guard let journalURL else {
            errorMessage = "No journal file found. Configure one in Settings or create ~/.hledger.journal."
            return
        }

        guard let hledgerPath = detectionResult?.hledgerPath else {
            errorMessage = "hledger binary not found."
            return
        }

        activeBackend = HledgerBackend(binaryPath: hledgerPath, journalFile: journalURL)
        errorMessage = nil
    }

    /// Load transactions for the current period.
    func loadTransactions() async {
        guard let backend = activeBackend else { return }
        isLoading = true
        errorMessage = nil

        do {
            let query = searchQuery.isEmpty ? "date:\(currentPeriod)" : searchQuery
            transactions = try await backend.loadTransactions(query: query, reversed: true)
        } catch {
            errorMessage = error.localizedDescription
            transactions = []
        }

        if !transactions.isEmpty {
            extractCommodityStyles()
        }

        isLoading = false
    }

    /// Look up the commodity style for a given commodity, falling back to default.
    func styleForCommodity(_ commodity: String) -> AmountStyle {
        commodityStyles[commodity] ?? .default
    }

    /// Parse user-entered amount input from a form, automatically applying the
    /// journal's commodity style so European-format commodities round-trip
    /// correctly. **All form callsites must go through this method**, never
    /// call `PostingAmountParser.parse(_:)` directly. See #129.
    func parseFormAmount(_ input: String) -> Amount? {
        PostingAmountParser.parse(
            input,
            defaultCommodity: config.defaultCommodity,
            styleResolver: { [weak self] commodity in
                self?.commodityStyles[commodity]
            }
        )
    }

    /// Extract commodity styles from loaded transactions (zero I/O cost).
    private func extractCommodityStyles() {
        var styles: [String: AmountStyle] = [:]
        for txn in transactions {
            for posting in txn.postings {
                for amount in posting.amounts {
                    if !amount.commodity.isEmpty && styles[amount.commodity] == nil {
                        styles[amount.commodity] = amount.style
                    }
                    if let cost = amount.cost, !cost.commodity.isEmpty && styles[cost.commodity] == nil {
                        styles[cost.commodity] = cost.style
                    }
                }
            }
        }
        commodityStyles = styles
    }

    /// Load accounts list.
    func loadAccounts() async {
        guard let backend = activeBackend else { return }

        do {
            accounts = try await backend.loadAccounts()
            accountBalances = try await backend.loadAccountBalances()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Load journal stats.
    func loadStats() async {
        guard let backend = activeBackend else { return }

        do {
            journalStats = try await backend.loadJournalStats()
        } catch {
            print("Failed to load stats: \(error)")
        }
    }

    /// Resolve the summary period filter to an hledger period string.
    private func resolveSummaryPeriod() -> String? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let today = Date()

        switch config.summaryPeriod {
        case "month":
            let mf = DateFormatter(); mf.dateFormat = "yyyy-MM"
            return mf.string(from: today)
        case "lastmonth":
            guard let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: today) else { return nil }
            let mf = DateFormatter(); mf.dateFormat = "yyyy-MM"
            return mf.string(from: lastMonth)
        case "3m":
            guard let start = Calendar.current.date(byAdding: .month, value: -3, to: today) else { return nil }
            return "\(f.string(from: start))..\(f.string(from: today))"
        case "6m":
            guard let start = Calendar.current.date(byAdding: .month, value: -6, to: today) else { return nil }
            return "\(f.string(from: start))..\(f.string(from: today))"
        case "12m":
            guard let start = Calendar.current.date(byAdding: .month, value: -12, to: today) else { return nil }
            return "\(f.string(from: start))..\(f.string(from: today))"
        case "ytd":
            let year = Calendar.current.component(.year, from: today)
            return "\(year)-01-01..\(f.string(from: today))"
        default:
            return nil
        }
    }

    /// Load summary data (period-filtered breakdowns + all-time balances).
    func loadSummary() async {
        guard let backend = activeBackend else { return }

        let period = resolveSummaryPeriod()

        async let periodSummary = backend.loadPeriodSummary(period: period)
        async let monthSummary = backend.loadPeriodSummary(period: currentPeriod)
        let commodity = config.defaultCommodity
        async let expenses = backend.loadExpenseBreakdown(period: period, preferredCommodity: commodity)
        async let income = backend.loadIncomeBreakdown(period: period, preferredCommodity: commodity)
        async let liabs = backend.loadLiabilitiesBreakdown(preferredCommodity: commodity)
        async let assts = backend.loadAssetsBreakdown(preferredCommodity: commodity)

        summaryAllTime = try? await periodSummary
        summaryCurrentMonth = try? await monthSummary
        expenseBreakdown = (try? await expenses) ?? []
        incomeBreakdown = (try? await income) ?? []
        liabilities = (try? await liabs) ?? []
        assets = (try? await assts) ?? []

        multiCurrencyAccounts = (try? await backend.loadMultiCurrencyAccounts()) ?? []

        if config.investmentsEnabled {
            await loadInvestments(backend: backend)
        }
    }

    /// Load investment portfolio data.
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

        let tickers = config.priceTickers
        guard !tickers.isEmpty else { return }

        isFetchingPrices = true
        let (pricesFile, failed) = await PriceService.getPricesFile(pricehistPath: config.pricehistBinaryPath, tickers: tickers)
        failedPriceTickers = failed
        if let pricesFile {
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

    /// Load period summary for transaction view cards.
    func loadPeriodSummary() async {
        guard let backend = activeBackend else { return }
        summaryCurrentMonth = try? await backend.loadPeriodSummary(period: currentPeriod)
    }

    /// Light reload after a transaction write (add/edit/delete/status).
    func reloadAfterWrite() async {
        async let txns: () = loadTransactions()
        async let summary: () = loadPeriodSummary()
        _ = await (txns, summary)
    }

    /// Full reload of all data.
    func reload() async {
        await loadTransactions()
        await loadAccounts()
        await loadStats()
        autoDetectCommodityIfNeeded()
        await loadSummary()
        dataVersion = UUID()
    }

    /// Auto-set the default commodity if the journal has exactly one and the user hasn't chosen.
    private func autoDetectCommodityIfNeeded() {
        guard !config.hasUserSetCommodity,
              let commodities = journalStats?.commodities,
              commodities.count == 1 else { return }
        config.defaultCommodity = commodities[0]
    }

    /// Navigate to previous month.
    func previousMonth() {
        currentPeriod = adjustMonth(currentPeriod, by: -1)
    }

    /// Navigate to next month.
    func nextMonth() {
        currentPeriod = adjustMonth(currentPeriod, by: 1)
    }

    /// Show new transaction form.
    func showNewTransaction() {
        showingNewTransaction = true
    }

    /// Context-aware Cmd+N: triggers new item based on current section.
    func triggerNew() {
        switch selectedSection {
        case .transactions: showingNewTransaction = true
        case .budget: showingNewBudgetRule = true
        case .recurring: showingNewRecurringRule = true
        default:
            selectedSection = .transactions
            showingNewTransaction = true
        }
    }

    // MARK: - Helpers

    private func adjustMonth(_ period: String, by months: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let date = formatter.date(from: period) else { return period }
        guard let adjusted = Calendar.current.date(byAdding: .month, value: months, to: date) else { return period }
        return formatter.string(from: adjusted)
    }

    /// Display-friendly period label (e.g., "March 2026").
    var periodLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let date = formatter.date(from: currentPeriod) else { return currentPeriod }
        let display = DateFormatter()
        display.dateFormat = "MMMM yyyy"
        return display.string(from: date)
    }
}
