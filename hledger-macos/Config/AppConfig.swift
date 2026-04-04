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
