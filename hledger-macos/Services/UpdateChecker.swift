/// Checks for app updates via GitHub Releases API.

import Foundation

struct AppRelease: Decodable {
    let tagName: String
    let name: String
    let htmlUrl: String
    let prerelease: Bool
    let assets: [ReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlUrl = "html_url"
        case prerelease
        case assets
    }
}

struct ReleaseAsset: Decodable {
    let name: String
    let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
    }
}

enum UpdateStatus: Equatable {
    case upToDate
    case updateAvailable(version: String, url: String, downloadUrl: String?)
    case error(String)
}

enum UpdateChecker {
    static let repoOwner = "thesmokinator"
    static let repoName = "hledger-macos"

    /// Current app version from Bundle.
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Check for updates against GitHub Releases.
    /// - Parameter includePrerelease: If true, also considers RC/pre-release versions.
    static func check(includePrerelease: Bool = false) async -> UpdateStatus {
        let urlString: String
        if includePrerelease {
            // List all releases, pick the first one
            urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases?per_page=1"
        } else {
            urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        }

        guard let url = URL(string: urlString) else {
            return .error("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return .error("GitHub API returned non-200 status")
            }

            let release: AppRelease
            if includePrerelease {
                let releases = try JSONDecoder().decode([AppRelease].self, from: data)
                guard let first = releases.first else {
                    return .upToDate
                }
                release = first
            } else {
                release = try JSONDecoder().decode(AppRelease.self, from: data)
            }

            let latestVersion = release.tagName.hasPrefix("v")
                ? String(release.tagName.dropFirst())
                : release.tagName

            let comparison = compareVersions(currentVersion, latestVersion)

            if comparison == .orderedAscending {
                let dmgAsset = release.assets.first { $0.name.hasSuffix(".dmg") }
                return .updateAvailable(
                    version: latestVersion,
                    url: release.htmlUrl,
                    downloadUrl: dmgAsset?.browserDownloadUrl
                )
            }

            return .upToDate
        } catch {
            return .error(error.localizedDescription)
        }
    }

    /// Compare two semantic version strings.
    /// Supports: "0.1.0", "0.1.0-rc2", "1.0.0"
    /// Returns .orderedAscending if v1 < v2, .orderedDescending if v1 > v2, .orderedSame if equal.
    static func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
        let (base1, pre1) = splitVersion(v1)
        let (base2, pre2) = splitVersion(v2)

        // Compare base versions (e.g., "0.1.0" vs "0.2.0")
        let baseResult = compareBaseVersions(base1, base2)
        if baseResult != .orderedSame { return baseResult }

        // Same base: compare pre-release
        // No pre-release > any pre-release (1.0.0 > 1.0.0-rc1)
        switch (pre1, pre2) {
        case (nil, nil): return .orderedSame
        case (nil, _): return .orderedDescending  // stable > pre-release
        case (_, nil): return .orderedAscending    // pre-release < stable
        case (let p1?, let p2?): return comparePrerelease(p1, p2)
        }
    }

    /// Split "0.1.0-rc2" into ("0.1.0", "rc2") or "0.1.0" into ("0.1.0", nil).
    static func splitVersion(_ version: String) -> (String, String?) {
        if let dashIndex = version.firstIndex(of: "-") {
            let base = String(version[version.startIndex..<dashIndex])
            let pre = String(version[version.index(after: dashIndex)...])
            return (base, pre)
        }
        return (version, nil)
    }

    /// Compare base version numbers like "0.1.0" vs "0.2.0".
    private static func compareBaseVersions(_ v1: String, _ v2: String) -> ComparisonResult {
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(parts1.count, parts2.count)

        for i in 0..<maxLen {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            if p1 < p2 { return .orderedAscending }
            if p1 > p2 { return .orderedDescending }
        }
        return .orderedSame
    }

    /// Compare pre-release tags like "rc1" vs "rc2", "alpha" vs "beta".
    private static func comparePrerelease(_ p1: String, _ p2: String) -> ComparisonResult {
        // Extract numeric suffix: "rc2" → 2
        let num1 = extractNumber(from: p1)
        let num2 = extractNumber(from: p2)
        let prefix1 = p1.trimmingCharacters(in: .decimalDigits)
        let prefix2 = p2.trimmingCharacters(in: .decimalDigits)

        // Different prefix: alphabetical
        if prefix1 != prefix2 {
            return prefix1 < prefix2 ? .orderedAscending : .orderedDescending
        }

        // Same prefix: compare numbers
        if num1 < num2 { return .orderedAscending }
        if num1 > num2 { return .orderedDescending }
        return .orderedSame
    }

    private static func extractNumber(from str: String) -> Int {
        let digits = str.filter(\.isNumber)
        return Int(digits) ?? 0
    }
}
