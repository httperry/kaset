//
//  HomeHeroSpotlightView.swift
//  Kaset
//
//  Grand 520pt Cinematic Hero Spotlight Stage with Spotify-style 16:9 artist
//  cover backdrop, smart ambient mesh fallback, and Liquid Glass controls.
//

import SwiftUI

// MARK: - HomeHeroSpotlightView

/// Grand 520pt Cinematic Featured Spotlight Stage with 16:9 artist backdrop and multi-item carousel.
struct HomeHeroSpotlightView: View {
    let heroItems: [HomeHeroItemPayload]
    let onPlayTarget: (HomePlayTarget) -> Void
    let onNavigateTarget: (HomePlayTarget) -> Void
    let onNavigateArtist: (Artist) -> Void

    @State private var selectedIndex: Int = 0
    @State private var palette: ColorExtractor.ColorPalette = .default
    @State private var isHovering = false

    private static let bannerHeight: CGFloat = 520
    private static let artworkSize: CGFloat = 280

    private var currentItem: HomeHeroItemPayload? {
        guard !self.heroItems.isEmpty else { return nil }
        let index = min(self.selectedIndex, self.heroItems.count - 1)
        return self.heroItems[index]
    }

    var body: some View {
        if let currentItem {
            ZStack(alignment: .bottomLeading) {
                // Layer 1: Dark Canvas Base
                Color(nsColor: NSColor(white: 0.05, alpha: 1.0))

                // Layer 2: Dynamic Backdrop (16:9 Artist Photography or Dreamy Blurred Backdrop)
                if currentItem.artistCoverURL != nil {
                    self.artistCoverBackdrop(for: currentItem)
                } else {
                    self.blurredMeshBackdrop(for: currentItem)
                }

                // Layer 3: Dynamic Ambient Color Mesh Gradient
                self.colorMeshLayer

                // Layer 4: Vignettes for Maximum Text Legibility & Contrast
                self.vignetteLayer

                // Layer 5: Foreground Hero Stage Content
                HStack(alignment: .bottom, spacing: 36) {
                    // Left 280x280 3D Artwork Box
                    self.artworkView(for: currentItem)

                    // Right Details & Action Bar
                    self.detailsView(for: currentItem)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 38)

                // Layer 6: Carousel Controls (Next/Prev and Dots)
                if self.heroItems.count > 1 {
                    self.carouselControls
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.bannerHeight)
            .clipShape(.rect(cornerRadius: 26))
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            )
            .contentShape(.rect(cornerRadius: 26))
            .onHover { hovering in
                withAnimation(AppAnimation.quick) {
                    self.isHovering = hovering
                }
            }
            .task(id: currentItem.id) {
                if let url = currentItem.thumbnailURL {
                    self.palette = await ColorExtractor.cachedPalette(for: url)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(localized: "Featured: \(currentItem.title) by \(currentItem.artistSubtitle)"))
        }
    }

    // MARK: - 16:9 Artist Cover Backdrop (Spotify Style)

    private func artistCoverBackdrop(for item: HomeHeroItemPayload) -> some View {
        let imageURL = item.artistCoverURL ?? item.thumbnailURL?.highQualityThumbnailURL

        return HStack(spacing: 0) {
            Spacer(minLength: 0)

            ZStack {
                if let url = imageURL {
                    CachedAsyncImage(
                        url: url,
                        targetSize: CGSize(width: 960, height: 540)
                    ) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 760, height: Self.bannerHeight)
                            .clipped()
                    } placeholder: {
                        EmptyView()
                    }
                }
            }
            .frame(width: 760, height: Self.bannerHeight)
            // Spotify-style smooth horizontal fade mask: transparent on left, solid on right
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black.opacity(0.20), location: 0.20),
                        .init(color: .black.opacity(0.75), location: 0.55),
                        .init(color: .black, location: 0.85),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .opacity(0.75)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Dreamy Blurred Mesh Backdrop (For Playlists/Collages)

    private func blurredMeshBackdrop(for item: HomeHeroItemPayload) -> some View {
        ZStack {
            if let url = item.thumbnailURL?.highQualityThumbnailURL {
                CachedAsyncImage(
                    url: url,
                    targetSize: CGSize(width: 600, height: 600)
                ) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(1.4)
                        .blur(radius: 75)
                        .opacity(0.45)
                } placeholder: {
                    EmptyView()
                }
            }

            // Atmospheric glass aura on the right
            HStack {
                Spacer()
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                self.palette.secondary.opacity(0.40),
                                self.palette.primary.opacity(0.15),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 220
                        )
                    )
                    .frame(width: 440, height: 440)
                    .blur(radius: 40)
                    .offset(x: 80, y: -20)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Color Mesh Layer

    private var colorMeshLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    self.palette.primary.opacity(0.60),
                    self.palette.secondary.opacity(0.35),
                    Color(nsColor: NSColor(white: 0.04, alpha: 0.95)),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    self.palette.primary.opacity(0.75),
                    self.palette.primary.opacity(0.18),
                    .clear,
                ],
                center: .init(x: 0.18, y: 0.70),
                startRadius: 20,
                endRadius: 400
            )
        }
        .allowsHitTesting(false)
    }

    // MARK: - Vignette Layer

    private var vignetteLayer: some View {
        ZStack {
            // Dark solid-to-clear fade from the left over text and album box
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.88), location: 0.0),
                    .init(color: .black.opacity(0.65), location: 0.45),
                    .init(color: .clear, location: 0.82),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            // Bottom subtle vignette
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.25),
                    .black.opacity(0.80),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
    }

    // MARK: - Artwork View (Left Box)

    private func artworkView(for item: HomeHeroItemPayload) -> some View {
        Button {
            // Clicking artwork immediately plays!
            self.onPlayTarget(item.playTarget)
        } label: {
            ZStack {
                if let url = item.thumbnailURL?.highQualityThumbnailURL {
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
                                    .font(.system(size: 64))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                    }
                } else {
                    Rectangle()
                        .fill(self.palette.primary.opacity(0.35))
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 64))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                }

                // Centered Hover Play Icon
                Circle()
                    .fill(.black.opacity(self.isHovering ? 0.60 : 0.0))
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: 2)
                            .opacity(self.isHovering ? 1.0 : 0.0)
                    }
                    .animation(AppAnimation.quick, value: self.isHovering)
            }
            .frame(width: Self.artworkSize, height: Self.artworkSize)
            .clipShape(.rect(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(.white.opacity(0.24), lineWidth: 1.5)
            )
            .shadow(color: self.palette.primary.opacity(0.65), radius: 56, x: 0, y: 18)
            .shadow(color: .black.opacity(0.45), radius: 22, x: 0, y: 10)
            .scaleEffect(self.isHovering ? 1.02 : 1.0)
            .animation(AppAnimation.spring, value: self.isHovering)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Details & Action Buttons

    private func detailsView(for item: HomeHeroItemPayload) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Badge Pill
            if let badgeText = item.badgeText, !badgeText.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: self.badgeIcon(for: badgeText))
                        .font(.system(size: 11, weight: .bold))
                    Text(badgeText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(0.8)
                }
                .foregroundStyle(.white.opacity(0.95))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .compatGlass(interactive: false, in: .capsule)
            }

            // Big Title
            Button {
                self.onPlayTarget(item.playTarget)
            } label: {
                Text(item.title)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.60), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            // Artist Subtitle (Clicking artist navigates to artist!)
            if let artist = item.playTarget.artist {
                Button {
                    self.onNavigateArtist(artist)
                } label: {
                    Text(item.artistSubtitle)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            } else {
                Text(item.artistSubtitle)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
            }

            // Contextual Narrative
            if let editorial = item.editorialDescription, !editorial.isEmpty {
                Text(editorial)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
                .frame(height: 8)

            // Action Row
            HStack(spacing: 16) {
                // Primary Play Action
                Button {
                    self.onPlayTarget(item.playTarget)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text("Start Listening")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
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
                            .font(.system(size: 13, weight: .semibold))
                        Text("View Details")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
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
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .compatGlass(interactive: true, in: .circle)
                }
                .buttonStyle(.plain)
                .padding(.leading, 14)
                .opacity(self.isHovering ? 1.0 : 0.0)

                Spacer()

                // Next
                Button {
                    withAnimation(AppAnimation.smooth) {
                        self.selectedIndex = (self.selectedIndex + 1) % self.heroItems.count
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .compatGlass(interactive: true, in: .circle)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 14)
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
                .padding(.bottom, 14)
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
