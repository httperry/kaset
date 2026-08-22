import SwiftUI

// MARK: - FixedProgressView

/// A ProgressView wrapper with explicit frame sizing to prevent AppKit Auto Layout constraint warnings.
/// The standard ProgressView on macOS can produce spurious warnings like:
/// "has a maximum length that doesn't satisfy min <= max"
/// This wrapper provides a fixed frame to avoid these layout ambiguity issues.
struct FixedProgressView: View {
    let controlSize: ControlSize
    let scale: CGFloat

    init(controlSize: ControlSize = .regular, scale: CGFloat = 1.0) {
        self.controlSize = controlSize
        self.scale = scale
    }

    private var frameSize: CGFloat {
        switch self.controlSize {
        case .mini:
            return 12 * self.scale
        case .small:
            return 16 * self.scale
        case .regular:
            return 20 * self.scale
        case .large:
            return 24 * self.scale
        case .extraLarge:
            return 32 * self.scale
        @unknown default:
            return 20 * self.scale
        }
    }

    var body: some View {
        ProgressView()
            .controlSize(self.controlSize)
            .scaleEffect(self.scale)
            .frame(width: self.frameSize, height: self.frameSize)
    }
}

// MARK: - LoadingView

/// Reusable loading indicator view with optional message.
/// Includes a pulsing animation for visual feedback.
struct LoadingView: View {
    let message: String

    /// Whether to show skeleton placeholders instead of just a spinner.
    let showSkeleton: Bool

    /// Number of skeleton sections to show.
    let skeletonSectionCount: Int

    init(
        _ message: String = String(localized: "Loading..."),
        showSkeleton: Bool = false,
        skeletonSectionCount: Int = 3
    ) {
        self.message = message
        self.showSkeleton = showSkeleton
        self.skeletonSectionCount = skeletonSectionCount
    }

    var body: some View {
        if self.showSkeleton {
            self.skeletonContent
        } else {
            self.spinnerContent
        }
    }

    private var spinnerContent: some View {
        VStack(spacing: 16) {
            FixedProgressView(controlSize: .regular)
            Text(self.message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var skeletonContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                ForEach(0 ..< self.skeletonSectionCount, id: \.self) { _ in
                    SkeletonSectionView()
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
}

// MARK: - HomeLoadingView

/// A specialized loading view for the home screen matching the modernized Grand Hero Spotlight layout.
struct HomeLoadingView: View {
    @State private var stageWidth: CGFloat = 1000

    private var responsiveBannerHeight: CGFloat {
        min(480, max(300, self.stageWidth * 0.40))
    }

    private var responsiveArtworkSize: CGFloat {
        min(190, max(110, self.responsiveBannerHeight * 0.40))
    }

    private var responsiveStagePadding: CGFloat {
        min(28, max(16, self.stageWidth * 0.026))
    }

    private var responsiveContentSpacing: CGFloat {
        min(28, max(14, self.stageWidth * 0.024))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                // Top Greeting Skeleton
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonView.rectangle(cornerRadius: 6)
                        .frame(width: 280, height: 28)
                    SkeletonView.rectangle(cornerRadius: 4)
                        .frame(width: 380, height: 14)
                }
                .padding(.horizontal, DetailContentLayout.horizontalInset)
                .padding(.top, 4)

                // Grand Hero Spotlight Stage Skeleton
                ZStack(alignment: .bottomLeading) {
                    // Base Card
                    RoundedRectangle(cornerRadius: min(22, max(16, self.responsiveBannerHeight * 0.05)))
                        .fill(Color(nsColor: NSColor(white: 0.12, alpha: 0.85)))
                        .frame(height: self.responsiveBannerHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: min(22, max(16, self.responsiveBannerHeight * 0.05)))
                                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                        )

                    // Bottom-Left Foreground Stage Content Skeleton
                    HStack(alignment: .bottom, spacing: self.responsiveContentSpacing) {
                        SkeletonView.rectangle(cornerRadius: min(16, max(10, self.responsiveArtworkSize * 0.085)))
                            .frame(width: self.responsiveArtworkSize, height: self.responsiveArtworkSize)

                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonView.capsule
                                .frame(width: 70, height: 18)
                            SkeletonView.rectangle(cornerRadius: 6)
                                .frame(width: min(240, max(140, self.stageWidth * 0.22)), height: min(28, max(18, self.stageWidth * 0.026)))
                            SkeletonView.rectangle(cornerRadius: 4)
                                .frame(width: min(160, max(100, self.stageWidth * 0.16)), height: 14)
                            HStack(spacing: 10) {
                                SkeletonView.capsule
                                    .frame(width: min(100, max(75, self.stageWidth * 0.10)), height: 32)
                                SkeletonView.capsule
                                    .frame(width: min(90, max(70, self.stageWidth * 0.09)), height: 32)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.leading, self.responsiveStagePadding)
                    .padding(.bottom, self.responsiveStagePadding)

                    // Bottom-Right Pagination Pill Skeleton
                    VStack {
                        Spacer(minLength: 0)
                        HStack {
                            Spacer(minLength: 0)
                            HStack(spacing: 5) {
                                SkeletonView.circle.frame(width: 14, height: 14)
                                SkeletonView.capsule.frame(width: 14, height: 4)
                                SkeletonView.circle.frame(width: 5, height: 4)
                                SkeletonView.circle.frame(width: 5, height: 4)
                                SkeletonView.circle.frame(width: 14, height: 14)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .compatGlass(interactive: false, in: .capsule)
                        }
                        .padding(.trailing, self.responsiveStagePadding)
                        .padding(.bottom, self.responsiveStagePadding)
                    }
                }
                .padding(.horizontal, DetailContentLayout.horizontalInset)
                .onGeometryChange(for: CGFloat.self) { geo in
                    geo.size.width
                } action: { newWidth in
                    if newWidth > 0, abs(newWidth - self.stageWidth) > 2 {
                        self.stageWidth = newWidth
                    }
                }

                // Jump Back In Shelf Skeleton
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        SkeletonView.rectangle(cornerRadius: 4)
                            .frame(width: 160, height: 20)
                        Spacer()
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(0 ..< 6, id: \.self) { _ in
                                VStack(alignment: .leading, spacing: 8) {
                                    SkeletonView.rectangle(cornerRadius: 12)
                                        .frame(width: 170, height: 170)
                                    SkeletonView.rectangle(cornerRadius: 4)
                                        .frame(width: 120, height: 14)
                                    SkeletonView.rectangle(cornerRadius: 4)
                                        .frame(width: 80, height: 12)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DetailContentLayout.horizontalInset)

                // Additional Feed Sections
                ForEach(0 ..< 2, id: \.self) { _ in
                    SkeletonSectionView()
                        .padding(.horizontal, DetailContentLayout.horizontalInset)
                }
            }
            .padding(.vertical, 20)
        }
    }
}

#Preview {
    VStack {
        LoadingView("Loading your music...")
        Divider()
        LoadingView("Loading...", showSkeleton: true, skeletonSectionCount: 2)
    }
    .frame(width: 600, height: 800)
}
