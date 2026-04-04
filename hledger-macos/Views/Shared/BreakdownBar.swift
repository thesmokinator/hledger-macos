/// Reusable horizontal bar for breakdown sections.
/// Dynamic: bar width proportional to the ratio (largest item = full width).
/// Fixed: all bars are the same full length regardless of amount.

import SwiftUI

struct BreakdownBar: View {
    let ratio: Double
    let color: Color
    let mode: String

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.15))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.6))
                    .frame(width: max(0, geo.size.width * CGFloat(mode == "fixed" ? 1.0 : ratio)), height: 6)
            }
        }
        .frame(height: 6)
    }
}
