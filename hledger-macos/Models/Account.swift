/// Account-related models for hierarchical and flat account views.

import Foundation

/// A node in the account hierarchy tree.
struct AccountNode: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var fullPath: String
    var balance: String
    var depth: Int
    var children: [AccountNode] = []
    var expanded: Bool = true

    init(
        id: UUID = UUID(),
        name: String,
        fullPath: String,
        balance: String,
        depth: Int,
        children: [AccountNode] = [],
        expanded: Bool = true
    ) {
        self.id = id
        self.name = name
        self.fullPath = fullPath
        self.balance = balance
        self.depth = depth
        self.children = children
        self.expanded = expanded
    }

    /// Returns children if non-empty, nil otherwise (for OutlineGroup).
    var optionalChildren: [AccountNode]? {
        children.isEmpty ? nil : children
    }
}

/// An hledger account directive with optional metadata.
struct AccountDirective: Sendable {
    var name: String
    var comment: String = ""
    var tags: [String: String] = [:]
}
