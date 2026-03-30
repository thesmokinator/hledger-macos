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
    // MARK: - Initialization

    var isInitialized = false
    var detectionResult: BinaryDetectionResult?

    // MARK: - Config & Backend

    var config = AppConfig()
    var activeBackend: HledgerBackend?

    // MARK: - Navigation

    var selectedSection: NavigationSection = .summary

    // MARK: - Data

    var transactions: [Transaction] = []
    var accounts: [String] = []
    var accountBalances: [(String, String)] = []
    var journalStats: JournalStats?

    // MARK: - UI State

    var isLoading = false
    var errorMessage: String?
    var searchQuery = ""
    var showingNewTransaction = false

    // MARK: - Period Navigation

    var currentPeriod: String = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }()

    // MARK: - Actions

    /// Initialize the app: detect hledger and set up backend.
    func initialize() async {
        // Apply configured default section
        if let section = NavigationSection(rawValue: config.defaultSection) {
            selectedSection = section
        }

        let result = BinaryDetector.detect(customHledgerPath: config.hledgerBinaryPath)
        detectionResult = result

        if result.isFound {
            setupBackend()
            isInitialized = true
        }
    }

    /// Re-scan for hledger (used from onboarding and settings).
    func rescan() async {
        let result = BinaryDetector.detect(customHledgerPath: config.hledgerBinaryPath)
        detectionResult = result

        if result.isFound {
            setupBackend()
            isInitialized = true
        }
    }

    /// Set up the hledger backend.
    func setupBackend() {
        guard let hledgerPath = detectionResult?.hledgerPath else { return }

        let journalURL = JournalFileResolver.resolve(configuredPath: config.journalFilePath)

        guard let journalURL else {
            errorMessage = "No journal file found. Configure one in Settings or create ~/.hledger.journal."
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

        isLoading = false
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

    /// Reload all data for the current view.
    func reload() async {
        await loadTransactions()
        await loadAccounts()
        await loadStats()
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
