/// Reusable horizontal bar for breakdown sections.
/// Width is proportional to the ratio (0..1) of the available space.

import SwiftUI

struct BreakdownBar: View {
    let ratio: Double
    let color: Color

    var body: some View {
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
