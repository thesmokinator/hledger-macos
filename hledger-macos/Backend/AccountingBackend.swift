/// Backend error types and shared definitions.

import Foundation

/// Errors from hledger backend operations.
enum BackendError: LocalizedError {
    case binaryNotFound(String)
    case commandFailed(String)
    case parseError(String)
    case journalValidationFailed(String)
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let name):
            return "\(name) not found"
        case .commandFailed(let msg):
            return msg
        case .parseError(let msg):
            return "Parse error: \(msg)"
        case .journalValidationFailed(let msg):
            return "Validation failed: \(msg)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        }
    }
}

// Note: The AccountingBackend protocol has been removed. HledgerBackend is used
// directly since we only support hledger.
