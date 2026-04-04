/// Reusable horizontal bar for breakdown sections.
/// Renders as dynamic (fills available space) or fixed width based on config.

import SwiftUI

struct BreakdownBar: View {
    let ratio: Double
    let color: Color
    let mode: String

    private static let fixedWidth: CGFloat = 120

    var body: some View {
        if mode == "fixed" {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.15))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.6))
                    .frame(width: max(0, Self.fixedWidth * CGFloat(ratio)), height: 6)
            }
            .frame(width: Self.fixedWidth, height: 6, alignment: .leading)
        } else {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.6))
                        .frame(width: max(0, geo.size.width * CGFloat(ratio)), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}
