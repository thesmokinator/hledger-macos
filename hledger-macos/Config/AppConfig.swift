/// Application configuration backed by UserDefaults.

import SwiftUI

@Observable
final class AppConfig {
    /// Custom hledger binary path (empty = auto-detect).
    var hledgerBinaryPath: String {
        get { UserDefaults.standard.string(forKey: "hledgerBinaryPath") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "hledgerBinaryPath") }
    }

    /// Custom journal file path (empty = use resolution chain).
    var journalFilePath: String {
        get { UserDefaults.standard.string(forKey: "journalFilePath") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "journalFilePath") }
    }

    /// Default commodity for display.
    var defaultCommodity: String {
        get { UserDefaults.standard.string(forKey: "defaultCommodity") ?? "$" }
        set { UserDefaults.standard.set(newValue, forKey: "defaultCommodity") }
    }

    /// Whether the user has explicitly chosen a commodity in Settings.
    var hasUserSetCommodity: Bool {
        get { UserDefaults.standard.object(forKey: "hasUserSetCommodity") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "hasUserSetCommodity") }
    }

    /// Accounts view mode (flat or tree).
    var accountsViewMode: String {
        get { UserDefaults.standard.string(forKey: "accountsViewMode") ?? "flat" }
        set { UserDefaults.standard.set(newValue, forKey: "accountsViewMode") }
    }

    /// Default section to open on launch.
    var defaultSection: String {
        get { UserDefaults.standard.string(forKey: "defaultSection") ?? "summary" }
        set { UserDefaults.standard.set(newValue, forKey: "defaultSection") }
    }

    /// Whether the investments section is enabled in Summary.
    var investmentsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "investmentsEnabled") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "investmentsEnabled") }
    }

    /// Custom pricehist binary path (empty = not configured).
    var pricehistBinaryPath: String {
        get { UserDefaults.standard.string(forKey: "pricehistBinaryPath") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "pricehistBinaryPath") }
    }

    /// Appearance mode: "system", "light", "dark".
    var appearance: String {
        get { UserDefaults.standard.string(forKey: "appearance") ?? "system" }
        set { UserDefaults.standard.set(newValue, forKey: "appearance") }
    }

    /// Resolved ColorScheme from appearance setting.
    var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil // system
        }
    }

    /// Summary period filter: "month", "3m", "6m", "12m", "ytd".
    var summaryPeriod: String {
        get { UserDefaults.standard.string(forKey: "summaryPeriod") ?? "month" }
        set { UserDefaults.standard.set(newValue, forKey: "summaryPeriod") }
    }

    /// Whether the accounts tree view starts fully expanded.
    var accountsTreeExpanded: Bool {
        get { UserDefaults.standard.object(forKey: "accountsTreeExpanded") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "accountsTreeExpanded") }
    }

    /// Accounts sort order: "asc" or "desc".
    var accountsSortOrder: String {
        get { UserDefaults.standard.string(forKey: "accountsSortOrder") ?? "asc" }
        set { UserDefaults.standard.set(newValue, forKey: "accountsSortOrder") }
    }

    /// Portfolio sort order: "asc" or "desc".
    var portfolioSortMode: String {
        get { UserDefaults.standard.string(forKey: "portfolioSortMode") ?? "asc" }
        set { UserDefaults.standard.set(newValue, forKey: "portfolioSortMode") }
    }

    /// Whether the AI assistant is enabled.
    var aiEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "aiEnabled") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "aiEnabled") }
    }

    /// Default report type: "is" (Income Statement), "bs" (Balance Sheet), "cf" (Cash Flow).
    var defaultReportType: String {
        get { UserDefaults.standard.string(forKey: "defaultReportType") ?? "is" }
        set { UserDefaults.standard.set(newValue, forKey: "defaultReportType") }
    }

    /// Default report period range: 2, 3, 6, 12, or 0 (YTD).
    var defaultReportPeriod: Int {
        get { UserDefaults.standard.object(forKey: "defaultReportPeriod") as? Int ?? 6 }
        set { UserDefaults.standard.set(newValue, forKey: "defaultReportPeriod") }
    }

    /// Bar chart mode in Summary breakdowns: "dynamic" (fills available space) or "fixed" (consistent width).
    var barChartMode: String {
        get { UserDefaults.standard.string(forKey: "barChartMode") ?? "dynamic" }
        set { UserDefaults.standard.set(newValue, forKey: "barChartMode") }
    }

    /// Commodity-to-Yahoo-ticker mappings as JSON string (e.g. {"XDWD":"XDWD.DE"}).
    var priceTickers: [String: String] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "priceTickers"),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "priceTickers")
            }
        }
    }
}
