import AppKit
import SwiftUI

// MARK: - TopBarMarqueeText

/// Constrained marquee text view for the topbar location pill that hugs short titles
/// and automatically scrolls long titles with edge fade masks.
struct TopBarMarqueeText: View {
    let title: String
    var maxWidth: CGFloat = 200

    private var textWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let size = (self.title as NSString).size(withAttributes: [.font: font])
        return ceil(size.width)
    }

    var body: some View {
        if self.textWidth > self.maxWidth {
            PlayerBarMarqueeText(
                text: self.title,
                font: .system(size: 13, weight: .semibold),
                color: .primary,
                height: 16,
                reduceMotion: false
            )
            .frame(width: self.maxWidth, height: 16)
        } else {
            Text(self.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}
