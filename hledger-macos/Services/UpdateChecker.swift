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

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Check for updates. Fetches releases from GitHub, finds the newest,
    /// and compares with the current app version.
    static func check() async -> UpdateStatus {
        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases?per_page=10")!

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .error("GitHub API returned non-200 status")
            }

            let releases = try JSONDecoder().decode([AppRelease].self, from: data)
            guard !releases.isEmpty else { return .upToDate }

            // Find the newest release (first non-prerelease, or first overall if none stable)
            let best = releases.first(where: { !$0.prerelease }) ?? releases[0]

            let latestVersion = best.tagName.hasPrefix("v")
                ? String(best.tagName.dropFirst())
                : best.tagName

            if compareVersions(currentVersion, latestVersion) == .orderedAscending {
                let dmg = best.assets.first { $0.name.hasSuffix(".dmg") }
                return .updateAvailable(
                    version: latestVersion,
                    url: best.htmlUrl,
                    downloadUrl: dmg?.browserDownloadUrl
                )
            }

            return .upToDate
        } catch {
            return .error(error.localizedDescription)
        }
    }

    // MARK: - Version Comparison

    static func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
        let (base1, pre1) = splitVersion(v1)
        let (base2, pre2) = splitVersion(v2)

        let baseResult = compareBase(base1, base2)
        if baseResult != .orderedSame { return baseResult }

        switch (pre1, pre2) {
        case (nil, nil): return .orderedSame
        case (nil, _): return .orderedDescending
        case (_, nil): return .orderedAscending
        case (let p1?, let p2?): return comparePrerelease(p1, p2)
        }
    }

    static func splitVersion(_ version: String) -> (String, String?) {
        guard let dash = version.firstIndex(of: "-") else { return (version, nil) }
        return (String(version[..<dash]), String(version[version.index(after: dash)...]))
    }

    private static func compareBase(_ v1: String, _ v2: String) -> ComparisonResult {
        let p1 = v1.split(separator: ".").compactMap { Int($0) }
        let p2 = v2.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(p1.count, p2.count) {
            let a = i < p1.count ? p1[i] : 0
            let b = i < p2.count ? p2[i] : 0
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
        }
        return .orderedSame
    }

    private static func comparePrerelease(_ p1: String, _ p2: String) -> ComparisonResult {
        let prefix1 = p1.filter(\.isLetter)
        let prefix2 = p2.filter(\.isLetter)
        if prefix1 != prefix2 {
            return prefix1 < prefix2 ? .orderedAscending : .orderedDescending
        }
        let num1 = Int(p1.filter(\.isNumber)) ?? 0
        let num2 = Int(p2.filter(\.isNumber)) ?? 0
        if num1 < num2 { return .orderedAscending }
        if num1 > num2 { return .orderedDescending }
        return .orderedSame
    }
}
