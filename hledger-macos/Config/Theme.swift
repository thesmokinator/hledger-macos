/// Design tokens for consistent UI across the app.

import SwiftUI

enum Theme {
    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xxsPlus: CGFloat = 3
        static let xs: CGFloat = 4
        static let xsPlus: CGFloat = 6
        static let sm: CGFloat = 8
        static let smPlus: CGFloat = 10
        static let md: CGFloat = 12
        static let mdPlus: CGFloat = 14
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let huge: CGFloat = 40
    }

    // MARK: - Corner Radius

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 12
    }

    // MARK: - Card Styles

    static let cardBackground: some ShapeStyle = .quaternary.opacity(0.3)
    static let cardRadius = Radius.md

    // MARK: - Fonts

    enum Fonts {
        static let sectionTitle: Font = .headline
        static let cardLabel: Font = .body
        static let cardAmount: Font = .system(size: 28, weight: .bold, design: .rounded)
        static let rowLabel: Font = .callout
        static let rowAmount: Font = .system(.callout, design: .monospaced)
        static let caption: Font = .caption
        static let hint: Font = .caption
    }

    // MARK: - Row Heights

    enum RowHeight {
        static let standard: CGFloat = 28
        static let transaction: CGFloat = 36
    }
}
