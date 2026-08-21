//
//  HomeHeroSpotlightView.swift
//  Kaset
//
//  Cinematic Hero Spotlight Stage with high-res artist cover image backdrop,
//  concurrent prefetching, auto-advancing carousel, and Liquid Glass controls.
//

import SwiftUI

// MARK: - HomeHeroSpotlightView

/// Cinematic Featured Spotlight Stage with preloaded high-res artist backdrop, auto-advance, and external pagination pill.
struct HomeHeroSpotlightView: View {
    let heroItems: [HomeHeroItemPayload]
    var onFetchArtistBanner: (@Sendable (String) async -> URL?)?
    let onPlayTarget: (HomePlayTarget) -> Void
    let onNavigateTarget: (HomePlayTarget) -> Void
    let onNavigateArtist: (Artist) -> Void

    @State private var selectedIndex: Int = 0
    @State private var palette: ColorExtractor.ColorPalette = .default
    @State private var isHoveringCard = false
    @State private var isHoveringArtwork = false
    @State private var isHoveringPlay = false
    @State private var isHoveringDetails = false
    @State private var isHoveringPrev = false
    @State private var isHoveringNext = false
    @State private var artistBanners: [String: URL] = [:]

    private static let bannerHeight: CGFloat = 480
    private static let artworkSize: CGFloat = 190

    private var currentItem: HomeHeroItemPayload? {
        guard !self.heroItems.isEmpty else { return nil }
        let index = min(self.selectedIndex, self.heroItems.count - 1)
        return self.heroItems[index]
    }

    var body: some View {
        if let currentItem {
            // Main Hero Stage Card
            ZStack(alignment: .center) {
                // Layer 1: Translucent Base (De-darkened)
                Color(nsColor: NSColor(white: 0.10, alpha: 0.85))

                // Layer 2: Artist Cover Image on the Right
                self.artistCoverBackdrop(for: currentItem)
                    .id(currentItem.id)
                    .transition(.opacity)

                // Layer 3: Dynamic Ambient Color Mesh Gradient
                self.colorMeshLayer
                    .id(currentItem.id)
                    .transition(.opacity)

                // Layer 4: Soft Vignettes for Text Legibility without pitch blackness
                self.vignetteLayer

                // Layer 5: Foreground Hero Stage Content (Anchored to the bottom with equal 28pt margin)
                VStack {
                    Spacer(minLength: 0)

                    HStack(alignment: .bottom, spacing: 32) {
                        // Left 190x190 3D Artwork Box
                        self.artworkView(for: currentItem)

                        // Right Details & Action Bar
                        self.detailsView(for: currentItem)

                        Spacer(minLength: 0)

                        // Bottom-Right Integrated Navigation & Pagination Pill
                        if self.heroItems.count > 1 {
                            self.bottomRightPaginationPill
                        }
                    }
                    .padding(.leading, 28)
                    .padding(.trailing, 28)
                    .padding(.bottom, 28)
                }
                .id(currentItem.id)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                    removal: .opacity
                ))
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.bannerHeight)
            .clipShape(.rect(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)
            )
            .contentShape(.rect(cornerRadius: 22))
            .onHover { hovering in
                withAnimation(AppAnimation.quick) {
                    self.isHoveringCard = hovering
                }
            }
            .animation(AppAnimation.smooth, value: self.selectedIndex)
            .task(id: currentItem.id) {
                if let url = currentItem.thumbnailURL {
                    self.palette = await ColorExtractor.cachedPalette(for: url)
                }
            }
            // Pre-fetch all artist banners upfront concurrently across all hero items
            .task(id: self.heroItems.map(\.id)) {
                await withTaskGroup(of: (String, URL?).self) { group in
                    for item in self.heroItems {
                        let artistId = item.featuredArtistId ?? item.playTarget.artist?.id
                        if let artistId, !artistId.isEmpty, let fetcher = self.onFetchArtistBanner {
                            group.addTask {
                                let url = await fetcher(artistId)
                                return (item.id, url?.highQualityThumbnailURL)
                            }
                        }
                    }
                    for await (itemId, url) in group {
                        if let url {
                            withAnimation(AppAnimation.smooth) {
                                self.artistBanners[itemId] = url
                            }
                        }
                    }
                }
            }
            // Auto-advance carousel loop (pauses when user is hovering over card)
            .task(id: self.heroItems.map(\.id)) {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 6_000_000_000) // 6 seconds
                    guard !Task.isCancelled else { break }
                    if !self.isHoveringCard, self.heroItems.count > 1 {
                        withAnimation(AppAnimation.smooth) {
                            self.selectedIndex = (self.selectedIndex + 1) % self.heroItems.count
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(localized: "Featured: \(currentItem.title) by \(currentItem.artistSubtitle)"))
        }
    }

    // MARK: - Artist Cover Backdrop (Full-Span & Expansive)

    private func artistCoverBackdrop(for item: HomeHeroItemPayload) -> some View {
        let imageURL = self.artistBanners[item.id] ?? item.artistCoverURL ?? item.thumbnailURL?.highQualityThumbnailURL

        return GeometryReader { geo in
            ZStack(alignment: .trailing) {
                if let url = imageURL {
                    CachedAsyncImage(
                        url: url,
                        targetSize: CGSize(width: 1400, height: 700)
                    ) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } placeholder: {
                        EmptyView()
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Ambient Color Tint Layer

    private var colorMeshLayer: some View {
        ZStack {
            // Soft overall ambient tint
            LinearGradient(
                colors: [
                    self.palette.primary.opacity(0.20),
                    self.palette.secondary.opacity(0.08),
                    .clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Focused ambient glow around the lower-left artwork
            RadialGradient(
                colors: [
                    self.palette.primary.opacity(0.35),
                    self.palette.primary.opacity(0.08),
                    .clear,
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 480
            )
        }
        .allowsHitTesting(false)
    }

    // MARK: - Natural Ambient Vignette Layer (Focused on Bottom-Left Content)

    private var vignetteLayer: some View {
        ZStack {
            // Organic radial falloff shielding ONLY the lower-left text & artwork
            RadialGradient(
                stops: [
                    .init(color: .black.opacity(0.82), location: 0.0),
                    .init(color: .black.opacity(0.65), location: 0.28),
                    .init(color: .black.opacity(0.25), location: 0.55),
                    .init(color: .clear, location: 0.85),
                ],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 650
            )

            // Subtle bottom grounding gradient
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.60),
                    .init(color: .black.opacity(0.35), location: 1.0),
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
                                    .font(.system(size: 44))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                    }
                } else {
                    Rectangle()
                        .fill(self.palette.primary.opacity(0.35))
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 44))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                }

                // Centered Hover Play Icon
                Circle()
                    .fill(.black.opacity(self.isHoveringArtwork ? 0.60 : 0.0))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: 2)
                            .opacity(self.isHoveringArtwork ? 1.0 : 0.0)
                    }
                    .animation(AppAnimation.quick, value: self.isHoveringArtwork)
            }
            .frame(width: Self.artworkSize, height: Self.artworkSize)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.24), lineWidth: 1.5)
            )
            .shadow(color: self.palette.primary.opacity(0.55), radius: 36, x: 0, y: 12)
            .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 6)
            .scaleEffect(self.isHoveringArtwork ? 1.02 : 1.0)
            .animation(AppAnimation.spring, value: self.isHoveringArtwork)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(AppAnimation.quick) {
                self.isHoveringArtwork = hovering
            }
        }
    }

    // MARK: - Details & Action Buttons

    private func detailsView(for item: HomeHeroItemPayload) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Badge Pill (Only shown for meaningful tags like SUPERMIX / HEAVY ROTATION)
            if let badgeText = item.badgeText, !badgeText.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: self.badgeIcon(for: badgeText))
                        .font(.system(size: 9.5, weight: .bold))
                    Text(badgeText)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .tracking(0.5)
                }
                .foregroundStyle(.white.opacity(0.95))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .compatGlass(interactive: false, in: .capsule)
                .padding(.bottom, 10)
            }

            // Title (28pt compact and bold)
            Button {
                self.onPlayTarget(item.playTarget)
            } label: {
                Text(item.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.40), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)

            // Artist Subtitle (15pt medium)
            if let artist = item.playTarget.artist, artist.hasNavigableId {
                Button {
                    self.onNavigateArtist(artist)
                } label: {
                    Text(item.artistSubtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            } else {
                Text(item.artistSubtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .padding(.bottom, 8)
            }

            // Contextual Narrative (13pt, clean)
            if let editorial = item.editorialDescription, !editorial.isEmpty {
                Text(editorial)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 18)
            } else {
                Spacer()
                    .frame(height: 12)
            }

            // Action Row
            self.actionButtons(for: item)
        }
    }

    // MARK: - Action Buttons

    private func actionButtons(for item: HomeHeroItemPayload) -> some View {
        HStack(spacing: 12) {
            // Primary Play Capsule
            Button {
                self.onPlayTarget(item.playTarget)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12.5, weight: .bold))
                    Text("Play")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8.5)
                .background(.white, in: Capsule())
                .foregroundStyle(.black)
                .shadow(
                    color: self.palette.primary.opacity(self.isHoveringPlay ? 0.50 : 0.20),
                    radius: self.isHoveringPlay ? 12 : 6,
                    x: 0,
                    y: self.isHoveringPlay ? 3 : 2
                )
                .scaleEffect(self.isHoveringPlay ? 1.04 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(AppAnimation.spring) {
                    self.isHoveringPlay = hovering
                }
            }
            .accessibilityLabel(String(localized: "Play \(item.title)"))

            // Secondary View Details Capsule
            Button {
                self.onNavigateTarget(item.playTarget)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .medium))
                    Text("Details")
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8.5)
                .foregroundStyle(.white)
                .compatGlass(interactive: true, in: .capsule)
                .scaleEffect(self.isHoveringDetails ? 1.04 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(AppAnimation.spring) {
                    self.isHoveringDetails = hovering
                }
            }
        }
    }

    // MARK: - Unified External Pagination & Navigation Bar Pill

    // MARK: - Bottom-Right Navigation & Pagination Pill

    private var bottomRightPaginationPill: some View {
        HStack(spacing: 8) {
            // Previous Chevron Button
            Button {
                withAnimation(AppAnimation.smooth) {
                    self.selectedIndex = (self.selectedIndex - 1 + self.heroItems.count) % self.heroItems.count
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(self.isHoveringPrev ? .white : .white.opacity(0.70))
                    .frame(width: 26, height: 26)
                    .contentShape(.rect)
                    .scaleEffect(self.isHoveringPrev ? 1.15 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(AppAnimation.quick) {
                    self.isHoveringPrev = hovering
                }
            }

            // Indicator Dots
            HStack(spacing: 6) {
                ForEach(0 ..< self.heroItems.count, id: \.self) { index in
                    Capsule()
                        .fill(index == self.selectedIndex ? Color.white : Color.white.opacity(0.35))
                        .frame(width: index == self.selectedIndex ? 18 : 6, height: 5)
                        .animation(AppAnimation.smooth, value: self.selectedIndex)
                        .onTapGesture {
                            withAnimation(AppAnimation.smooth) {
                                self.selectedIndex = index
                            }
                        }
                }
            }
            .padding(.horizontal, 4)

            // Next Chevron Button
            Button {
                withAnimation(AppAnimation.smooth) {
                    self.selectedIndex = (self.selectedIndex + 1) % self.heroItems.count
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(self.isHoveringNext ? .white : .white.opacity(0.70))
                    .frame(width: 26, height: 26)
                    .contentShape(.rect)
                    .scaleEffect(self.isHoveringNext ? 1.15 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(AppAnimation.quick) {
                    self.isHoveringNext = hovering
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .compatGlass(interactive: true, in: .capsule)
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
