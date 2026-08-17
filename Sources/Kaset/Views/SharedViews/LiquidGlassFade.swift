import SwiftUI

/// A reusable edge-docked Liquid Glass gradient surface that dissolves seamlessly into the content.
///
/// Features:
/// - Decoupled Apple macOS Liquid Glass refraction layer (retains full blur strength).
/// - Dynamic mode-aware tint gradient (soft black in dark mode, soft white in light mode).
/// - Smooth cubic alpha easing to eliminate hard clipping edges.
/// - Available for topbars, player areas, and custom scroll fades.
struct LiquidGlassFade: View {
    @Environment(\.colorScheme) private var colorScheme

    let edge: VerticalEdge
    var height: CGFloat = 64
    var maxTintOpacity: Double?

    private var effectiveTintOpacity: Double {
        if let maxTintOpacity {
            return maxTintOpacity
        }
        return self.colorScheme == .dark ? 0.50 : 0.30
    }

    private var tintColor: Color {
        self.colorScheme == .dark ? Color.black : Color.white
    }

    private var startPoint: UnitPoint {
        self.edge == .top ? .top : .bottom
    }

    private var endPoint: UnitPoint {
        self.edge == .top ? .bottom : .top
    }

    var body: some View {
        ZStack(alignment: self.edge == .top ? .top : .bottom) {
            // 1. Pure Liquid Glass layer: full strength at the docked edge, fading smoothly to transparent
            Color.clear
                .compatGlass(interactive: false, in: Rectangle())
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0.0),
                            .init(color: .white.opacity(0.80), location: 0.45),
                            .init(color: .white.opacity(0.30), location: 0.75),
                            .init(color: .clear, location: 1.0),
                        ],
                        startPoint: self.startPoint,
                        endPoint: self.endPoint
                    )
                )

            // 2. Color tint layer: 50% transparent near docked edge, fading to 100% transparent (.clear)
            LinearGradient(
                stops: [
                    .init(color: self.tintColor.opacity(self.effectiveTintOpacity), location: 0.0),
                    .init(color: self.tintColor.opacity(self.effectiveTintOpacity * 0.70), location: 0.45),
                    .init(color: .clear, location: 1.0),
                ],
                startPoint: self.startPoint,
                endPoint: self.endPoint
            )
        }
        .frame(height: self.height)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(edges: self.edge == .top ? .top : .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Applies a reusable Liquid Glass gradient fade along the specified vertical edge.
    func liquidGlassFade(
        edge: VerticalEdge,
        height: CGFloat = 64,
        maxTintOpacity: Double? = nil
    ) -> some View {
        self.overlay(alignment: edge == .top ? .top : .bottom) {
            LiquidGlassFade(edge: edge, height: height, maxTintOpacity: maxTintOpacity)
        }
    }
}
