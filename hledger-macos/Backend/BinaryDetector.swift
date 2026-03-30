/// Detects the hledger CLI binary on the system.

import Foundation

/// Result of hledger binary detection.
struct BinaryDetectionResult: Sendable {
    let hledgerPath: String?

    var isFound: Bool { hledgerPath != nil }
}

/// Scans for the hledger binary in known paths and user-configured locations.
enum BinaryDetector {
    /// Common installation paths on macOS.
    private static let knownPaths = [
        "/opt/homebrew/bin/hledger",    // Apple Silicon Homebrew
        "/usr/local/bin/hledger",       // Intel Homebrew
        "/usr/bin/hledger",             // System
    ]

    /// Detect the hledger binary.
    ///
    /// Priority: custom path > known filesystem paths > which.
    static func detect(customHledgerPath: String = "") -> BinaryDetectionResult {
        let path = findHledger(customPath: customHledgerPath)
        return BinaryDetectionResult(hledgerPath: path)
    }

    /// Find the hledger binary.
    static func findHledger(customPath: String = "") -> String? {
        // 1. User-configured custom path
        if !customPath.isEmpty,
           FileManager.default.isExecutableFile(atPath: customPath) {
            return customPath
        }

        // 2. Check known filesystem paths directly (most reliable in GUI apps)
        for path in knownPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }
}
