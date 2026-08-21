//
//  HomeHeroSpotlightView.swift
//  Kaset
//
//  Grand 410pt 16:9 Cinematic Hero Spotlight Stage with multi-item carousel,
//  dynamic blurred artwork backdrop, and Liquid Glass controls.
//

import SwiftUI

// MARK: - HomeHeroSpotlightView

/// Grand 16:9 Cinematic Featured Spotlight Stage with multi-item carousel.
struct HomeHeroSpotlightView: View {
    let heroItems: [HomeHeroItemPayload]
    let onPlayTarget: (HomePlayTarget) -> Void
    let onNavigateTarget: (HomePlayTarget) -> Void
    let onNavigateArtist: (Artist) -> Void

    @State private var selectedIndex: Int = 0
    @State private var palette: ColorExtractor.ColorPalette = .default
    @State private var isHovering = false

    private static let bannerHeight: CGFloat = 410
    private static let artworkSize: CGFloat = 230

    private var currentItem: HomeHeroItemPayload? {
        guard !self.heroItems.isEmpty else { return nil }
        let index = min(self.selectedIndex, self.heroItems.count - 1)
        return self.heroItems[index]
    }

    var body: some View {
        if let currentItem {
            ZStack(alignment: .bottomLeading) {
                // Layer 1: Ambient Blurred Artwork Backdrop
                self.backdropLayer(for: currentItem)

                // Layer 2: Dynamic Radial Mesh Gradient
                self.colorMeshLayer

                // Layer 3: Dark Vignettes for Contrast
                self.vignetteLayer

                // Layer 4: Foreground Hero Stage Content
                HStack(alignment: .bottom, spacing: 32) {
                    // Left 230x230 Artwork Box
                    self.artworkView(for: currentItem)

                    // Right Details & Actions
                    self.detailsView(for: currentItem)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 34)

                // Layer 5: Carousel Controls (Next/Prev and Dots)
                if self.heroItems.count > 1 {
                    self.carouselControls
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.bannerHeight)
            .clipShape(.rect(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            )
            .contentShape(.rect(cornerRadius: 24))
            .onHover { hovering in
                withAnimation(AppAnimation.quick) {
                    self.isHovering = hovering
                }
            }
            .task(id: currentItem.thumbnailURL) {
                if let url = currentItem.thumbnailURL {
                    self.palette = await ColorExtractor.cachedPalette(for: url)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(localized: "Featured: \(currentItem.title) by \(currentItem.artistSubtitle)"))
        }
    }

    // MARK: - Backdrop Layers

    private func backdropLayer(for item: HomeHeroItemPayload) -> some View {
        ZStack {
            Color(nsColor: NSColor(white: 0.06, alpha: 1.0))

            if let url = item.thumbnailURL {
                CachedAsyncImage(
                    url: url,
                    targetSize: CGSize(width: 600, height: 600)
                ) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(1.4)
                        .blur(radius: 70)
                        .opacity(0.48)
                } placeholder: {
                    EmptyView()
                }
            }
        }
    }

    private var colorMeshLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    self.palette.primary.opacity(0.65),
                    self.palette.secondary.opacity(0.40),
                    Color(nsColor: NSColor(white: 0.04, alpha: 0.95)),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    self.palette.primary.opacity(0.75),
                    self.palette.primary.opacity(0.20),
                    .clear,
                ],
                center: .init(x: 0.22, y: 0.65),
                startRadius: 20,
                endRadius: 320
            )
            .allowsHitTesting(false)
        }
    }

    private var vignetteLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.25),
                    .black.opacity(0.80),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    .black.opacity(0.45),
                    .clear,
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .allowsHitTesting(false)
    }

    // MARK: - Artwork View

    private func artworkView(for item: HomeHeroItemPayload) -> some View {
        Button {
            // Clicking artwork immediately plays!
            self.onPlayTarget(item.playTarget)
        } label: {
            ZStack {
                if let url = item.thumbnailURL {
                    CachedAsyncImage(
                        url: url,
                        targetSize: CGSize(width: Self.artworkSize, height: Self.artworkSize)
                    ) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(self.palette.primary.opacity(0.35))
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 54))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                    }
                } else {
                    Rectangle()
                        .fill(self.palette.primary.opacity(0.35))
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 54))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                }

                // Centered Hover Play Icon
                Circle()
                    .fill(.black.opacity(self.isHovering ? 0.60 : 0.0))
                    .frame(width: 58, height: 58)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: 2)
                            .opacity(self.isHovering ? 1.0 : 0.0)
                    }
                    .animation(AppAnimation.quick, value: self.isHovering)
            }
            .frame(width: Self.artworkSize, height: Self.artworkSize)
            .clipShape(.rect(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.white.opacity(0.24), lineWidth: 1.5)
            )
            .shadow(color: self.palette.primary.opacity(0.60), radius: 48, x: 0, y: 16)
            .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 8)
            .scaleEffect(self.isHovering ? 1.02 : 1.0)
            .animation(AppAnimation.spring, value: self.isHovering)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Details & Action Buttons

    private func detailsView(for item: HomeHeroItemPayload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Badge Pill
            if let badgeText = item.badgeText, !badgeText.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: self.badgeIcon(for: badgeText))
                        .font(.system(size: 10, weight: .bold))
                    Text(badgeText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.6)
                }
                .foregroundStyle(.white.opacity(0.95))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .compatGlass(interactive: false, in: .capsule)
            }

            // Big Title
            Button {
                self.onPlayTarget(item.playTarget)
            } label: {
                Text(item.title)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.55), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            // Artist Subtitle (Clicking artist navigates to artist!)
            if let artist = item.playTarget.artist {
                Button {
                    self.onNavigateArtist(artist)
                } label: {
                    Text(item.artistSubtitle)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            } else {
                Text(item.artistSubtitle)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
            }

            // Contextual Narrative
            if let editorial = item.editorialDescription, !editorial.isEmpty {
                Text(editorial)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
                .frame(height: 6)

            // Action Row
            HStack(spacing: 14) {
                // Primary Play Action
                Button {
                    self.onPlayTarget(item.playTarget)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Start Listening")
                            .font(.system(size: 13.5, weight: .semibold))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .compatGlassProminentButton()
                .tint(.white)
                .foregroundStyle(.black)
                .accessibilityLabel(String(localized: "Start listening to \(item.title)"))

                // Secondary View Details Action
                Button {
                    self.onNavigateTarget(item.playTarget)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("View Details")
                            .font(.system(size: 13.5, weight: .medium))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .compatGlass(interactive: true, in: .capsule)
            }
        }
    }

    // MARK: - Carousel Controls

    private var carouselControls: some View {
        ZStack {
            // Next / Prev Floating Chevrons
            HStack {
                // Prev
                Button {
                    withAnimation(AppAnimation.smooth) {
                        self.selectedIndex = (self.selectedIndex - 1 + self.heroItems.count) % self.heroItems.count
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .compatGlass(interactive: true, in: .circle)
                }
                .buttonStyle(.plain)
                .padding(.leading, 12)
                .opacity(self.isHovering ? 1.0 : 0.0)

                Spacer()

                // Next
                Button {
                    withAnimation(AppAnimation.smooth) {
                        self.selectedIndex = (self.selectedIndex + 1) % self.heroItems.count
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .compatGlass(interactive: true, in: .circle)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
                .opacity(self.isHovering ? 1.0 : 0.0)
            }
            .animation(AppAnimation.quick, value: self.isHovering)

            // Bottom Page Dots
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0 ..< self.heroItems.count, id: \.self) { index in
                        Circle()
                            .fill(index == self.selectedIndex ? .white : .white.opacity(0.35))
                            .frame(width: index == self.selectedIndex ? 8 : 6, height: index == self.selectedIndex ? 8 : 6)
                            .animation(AppAnimation.quick, value: self.selectedIndex)
                            .onTapGesture {
                                withAnimation(AppAnimation.smooth) {
                                    self.selectedIndex = index
                                }
                            }
                    }
                }
                .padding(.bottom, 12)
            }
        }
    }

    private func badgeIcon(for text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("supermix") {
            return "sparkles"
        }
        if lower.contains("rotation") {
            return "flame.fill"
        }
        if lower.contains("album") {
            return "square.stack.fill"
        }
        return "music.note"
    }
}
