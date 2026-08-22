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
    var onFetchPlaylistTracks: (@Sendable (String) async -> [URL])?
    let onPlayTarget: (HomePlayTarget) -> Void
    let onNavigateTarget: (HomePlayTarget) -> Void
    let onNavigateArtist: (Artist) -> Void
    var contextMenu: ((HomePlayTarget) -> AnyView)?

    @State private var selectedIndex: Int = 0
    @State private var palette: ColorExtractor.ColorPalette = .default
    @State private var isHoveringCard = false
    @State private var isHoveringArtwork = false
    @State private var isHoveringPlay = false
    @State private var isHoveringDetails = false
    @State private var isHoveringPrev = false
    @State private var isHoveringNext = false
    @State private var artistBanners: [String: URL] = [:]
    @State private var playlistArtworks: [String: [URL]] = [:]
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

    private var responsiveTitleFontSize: CGFloat {
        min(28, max(18, self.stageWidth * 0.026))
    }

    private var responsiveSubtitleFontSize: CGFloat {
        min(15, max(12, self.stageWidth * 0.014))
    }

    private var isCompact: Bool {
        self.stageWidth < 760
    }

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

                // Layer 2: Full-Span Artist Cover or Dynamic Multi-Track Diagonal Slices
                self.backdropView(for: currentItem)
                    .id(currentItem.id)
                    .transition(.opacity)

                // Layer 3: Dynamic Ambient Color Mesh Gradient
                self.colorMeshLayer
                    .id(currentItem.id)
                    .transition(.opacity)

                // Layer 4: Soft Vignettes for Text Legibility without pitch blackness
                self.vignetteLayer

                // Layer 5: Foreground Hero Stage Content (Anchored to bottom-left with equal margin)
                VStack {
                    Spacer(minLength: 0)

                    HStack(alignment: .bottom, spacing: self.responsiveContentSpacing) {
                        // Left 3D Artwork Box
                        self.artworkView(for: currentItem)

                        // Right Details & Action Bar
                        self.detailsView(for: currentItem)

                        Spacer(minLength: 0)
                    }
                    .padding(.leading, self.responsiveStagePadding)
                    .padding(.trailing, self.responsiveStagePadding)
                    .padding(.bottom, self.responsiveStagePadding)
                }
                .id(currentItem.id)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                    removal: .opacity
                ))

                // Layer 6: Static Bottom-Right Navigation Pill (Stable, never remounts or re-transitions)
                if self.heroItems.count > 1 {
                    VStack {
                        Spacer(minLength: 0)
                        HStack {
                            Spacer(minLength: 0)
                            self.bottomRightPaginationPill
                        }
                        .padding(.trailing, self.responsiveStagePadding)
                        .padding(.bottom, self.responsiveStagePadding)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: self.responsiveBannerHeight)
            .clipShape(.rect(cornerRadius: min(22, max(16, self.responsiveBannerHeight * 0.05))))
            .overlay(
                RoundedRectangle(cornerRadius: min(22, max(16, self.responsiveBannerHeight * 0.05)))
                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)
            )
            .contentShape(.rect(cornerRadius: min(22, max(16, self.responsiveBannerHeight * 0.05))))
            .onGeometryChange(for: CGFloat.self) { geo in
                geo.size.width
            } action: { newWidth in
                if newWidth > 0, abs(newWidth - self.stageWidth) > 2 {
                    self.stageWidth = newWidth
                }
            }
            .contextMenu {
                if let contextMenu {
                    contextMenu(currentItem.playTarget)
                }
            }
            .onHover { hovering in
                withAnimation(AppAnimation.quick) {
                    self.isHoveringCard = hovering
                }
            }
            .task(id: currentItem.id) {
                if let url = currentItem.thumbnailURL {
                    self.palette = await ColorExtractor.cachedPalette(for: url)
                }
            }
            // Pre-fetch all artist banners and playlist track artworks upfront concurrently
            .task(id: self.heroItems.map(\.id)) {
                await withTaskGroup(of: (String, URL?, [URL]?).self) { group in
                    for item in self.heroItems {
                        // Skip if already in HomeHeroArtworkStore
                        let hasPlaylist = HomeHeroArtworkStore.playlistArtworks[item.id] != nil || item.multiTrackArtworks != nil
                        let hasArtist = HomeHeroArtworkStore.artistBanners[item.id] != nil || item.artistCoverURL != nil
                        if hasPlaylist, hasArtist {
                            continue
                        }

                        group.addTask {
                            var bannerURL: URL?
                            var trackURLs: [URL]?

                            switch item.playTarget {
                            case .playlist:
                                if !hasPlaylist, let fetcher = self.onFetchPlaylistTracks {
                                    let urls = await fetcher(item.playTarget.id)
                                    if !urls.isEmpty {
                                        trackURLs = urls.compactMap { $0.ultraHighQualityThumbnailURL ?? $0 }
                                    }
                                }
                                if !hasArtist, let artistId = item.featuredArtistId ?? item.playTarget.artist?.id,
                                   !artistId.isEmpty, let fetcher = self.onFetchArtistBanner
                                {
                                    bannerURL = await (fetcher(artistId))?.ultraHighQualityThumbnailURL
                                }
                            case .album, .song, .artist:
                                if !hasArtist, let artistId = item.featuredArtistId ?? item.playTarget.artist?.id,
                                   !artistId.isEmpty, let fetcher = self.onFetchArtistBanner
                                {
                                    bannerURL = await (fetcher(artistId))?.ultraHighQualityThumbnailURL
                                }
                            }

                            return (item.id, bannerURL, trackURLs)
                        }
                    }
                    for await (itemId, bannerURL, trackURLs) in group {
                        if let bannerURL {
                            HomeHeroArtworkStore.artistBanners[itemId] = bannerURL
                            self.artistBanners[itemId] = bannerURL
                        }
                        if let trackURLs {
                            HomeHeroArtworkStore.playlistArtworks[itemId] = trackURLs
                            self.playlistArtworks[itemId] = trackURLs
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

    // MARK: - Backdrop View (Dynamic Multi-Artist Diagonal Slices or Full-Span Artist Cover)

    private func backdropView(for item: HomeHeroItemPayload) -> some View {
        let isPlaylist = switch item.playTarget {
        case .playlist:
            true
        default:
            false
        }

        // For playlists with multi-track artworks, render 4-5 diagonal split slice collage
        let playlistURLs = item.multiTrackArtworks ?? HomeHeroArtworkStore.playlistArtworks[item.id] ?? self.playlistArtworks[item.id]
        if isPlaylist, let playlistURLs, playlistURLs.count >= 2 {
            return AnyView(self.diagonalSlicesBackdrop(urls: playlistURLs))
        }

        // Single artist cover or high-res thumbnail (never fall back to 4-box low-res playlist thumbnail)
        let imageURL = item.artistCoverURL?.ultraHighQualityThumbnailURL
            ?? HomeHeroArtworkStore.artistBanners[item.id]
            ?? self.artistBanners[item.id]
            ?? (isPlaylist ? nil : item.thumbnailURL?.ultraHighQualityThumbnailURL)
        return AnyView(self.singleImageBackdrop(imageURL: imageURL))
    }

    private func singleImageBackdrop(imageURL: URL?) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .trailing) {
                if let url = imageURL {
                    CachedAsyncImage(
                        url: url,
                        targetSize: CGSize(width: 1920, height: 1080)
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

    private func diagonalSlicesBackdrop(urls: [URL]) -> some View {
        let count = min(max(urls.count, 2), 5)
        let sliceURLs = Array(urls.prefix(count))
        let slant: CGFloat = 65

        return GeometryReader { geo in
            ZStack {
                // Slices
                ForEach(0 ..< sliceURLs.count, id: \.self) { idx in
                    let url = sliceURLs[idx]
                    let totalCount = CGFloat(count)
                    let effectiveWidth = geo.size.width + slant
                    let sliceWidth = effectiveWidth / totalCount
                    let midpointX = (CGFloat(idx) + 0.5) * sliceWidth - slant / 2

                    CachedAsyncImage(
                        url: url,
                        targetSize: CGSize(width: 1200, height: 1200)
                    ) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: max(sliceWidth + slant + 60, geo.size.height * 1.05), height: geo.size.height)
                            .clipped()
                    } placeholder: {
                        Color(nsColor: NSColor(white: 0.12, alpha: 1.0))
                    }
                    .position(x: midpointX, y: geo.size.height / 2)
                    .clipShape(DiagonalSliceShape(index: idx, sliceCount: count, slant: slant))
                }

                // Divider Lines between Slices
                if count > 1 {
                    ForEach(1 ..< count, id: \.self) { idx in
                        DiagonalSliceDividerShape(index: idx, sliceCount: count, slant: slant)
                            .stroke(
                                LinearGradient(
                                    stops: [
                                        .init(color: .white.opacity(0.30), location: 0.0),
                                        .init(color: .white.opacity(0.10), location: 0.75),
                                        .init(color: .clear, location: 1.0),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
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
                endRadius: max(320, self.responsiveBannerHeight * 1.0)
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
                startRadius: 20,
                endRadius: max(380, self.responsiveBannerHeight * 1.35)
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
        let size = self.responsiveArtworkSize
        let cornerRadius = min(16, max(10, size * 0.085))

        return Button {
            self.onPlayTarget(item.playTarget)
        } label: {
            ZStack {
                if let url = item.thumbnailURL?.highQualityThumbnailURL {
                    CachedAsyncImage(
                        url: url,
                        targetSize: CGSize(width: size, height: size)
                    ) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(self.palette.primary.opacity(0.35))
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: size * 0.23))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                    }
                } else {
                    Rectangle()
                        .fill(self.palette.primary.opacity(0.35))
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: size * 0.23))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                }

                // Centered Hover Play Icon
                Circle()
                    .fill(.black.opacity(self.isHoveringArtwork ? 0.60 : 0.0))
                    .frame(width: min(52, max(36, size * 0.28)), height: min(52, max(36, size * 0.28)))
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: min(20, max(14, size * 0.11)), weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: 1.5)
                            .opacity(self.isHoveringArtwork ? 1.0 : 0.0)
                    }
                    .animation(AppAnimation.quick, value: self.isHoveringArtwork)
            }
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.white.opacity(0.24), lineWidth: 1.5)
            )
            .shadow(color: self.palette.primary.opacity(0.55), radius: min(36, size * 0.20), x: 0, y: min(12, size * 0.06))
            .shadow(color: .black.opacity(0.35), radius: min(14, size * 0.08), x: 0, y: min(6, size * 0.03))
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
                HStack(spacing: 4) {
                    Image(systemName: self.badgeIcon(for: badgeText))
                        .font(.system(size: self.isCompact ? 8.5 : 9.5, weight: .bold))
                    Text(badgeText)
                        .font(.system(size: self.isCompact ? 9.5 : 10.5, weight: .bold, design: .rounded))
                        .tracking(0.5)
                }
                .foregroundStyle(.white.opacity(0.95))
                .padding(.horizontal, self.isCompact ? 8 : 10)
                .padding(.vertical, self.isCompact ? 3 : 4)
                .compatGlass(interactive: false, in: .capsule)
                .padding(.bottom, min(10, max(4, self.responsiveBannerHeight * 0.02)))
            }

            // Title
            Button {
                self.onPlayTarget(item.playTarget)
            } label: {
                Text(item.title)
                    .font(.system(size: self.responsiveTitleFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.40), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 3)

            // Artist Subtitle
            if let artist = item.playTarget.artist, artist.hasNavigableId {
                Button {
                    self.onNavigateArtist(artist)
                } label: {
                    Text(item.artistSubtitle)
                        .font(.system(size: self.responsiveSubtitleFontSize, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .padding(.bottom, min(8, max(4, self.responsiveBannerHeight * 0.015)))
            } else {
                Text(item.artistSubtitle)
                    .font(.system(size: self.responsiveSubtitleFontSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .padding(.bottom, min(8, max(4, self.responsiveBannerHeight * 0.015)))
            }

            // Contextual Narrative (clean - omitted or truncated if compact)
            if let editorial = item.editorialDescription, !editorial.isEmpty, self.responsiveBannerHeight >= 340 {
                Text(editorial)
                    .font(.system(size: min(13, max(11, self.stageWidth * 0.012))))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(self.stageWidth < 850 ? 1 : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, min(14, max(8, self.responsiveBannerHeight * 0.03)))
            } else {
                Spacer()
                    .frame(height: min(10, max(4, self.responsiveBannerHeight * 0.02)))
            }

            // Action Row
            self.actionButtons(for: item)
        }
    }

    // MARK: - Action Buttons

    private func actionButtons(for item: HomeHeroItemPayload) -> some View {
        HStack(spacing: min(12, max(8, self.stageWidth * 0.012))) {
            // Primary Play Capsule
            Button {
                self.onPlayTarget(item.playTarget)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: self.isCompact ? 11 : 12.5, weight: .bold))
                    Text("Play")
                        .font(.system(size: self.isCompact ? 11.5 : 13, weight: .semibold))
                }
                .padding(.horizontal, self.isCompact ? 15 : 20)
                .padding(.vertical, self.isCompact ? 6.5 : 8.5)
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
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: self.isCompact ? 11 : 12, weight: .medium))
                    Text("Details")
                        .font(.system(size: self.isCompact ? 11.5 : 13, weight: .medium))
                }
                .padding(.horizontal, self.isCompact ? 12 : 16)
                .padding(.vertical, self.isCompact ? 6.5 : 8.5)
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
        HStack(spacing: self.isCompact ? 5 : 8) {
            // Previous Chevron Button
            Button {
                withAnimation(AppAnimation.smooth) {
                    self.selectedIndex = (self.selectedIndex - 1 + self.heroItems.count) % self.heroItems.count
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: self.isCompact ? 9.5 : 11, weight: .bold))
                    .foregroundStyle(self.isHoveringPrev ? .white : .white.opacity(0.70))
                    .frame(width: self.isCompact ? 20 : 26, height: self.isCompact ? 20 : 26)
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
            HStack(spacing: self.isCompact ? 4 : 6) {
                ForEach(0 ..< self.heroItems.count, id: \.self) { index in
                    Capsule()
                        .fill(index == self.selectedIndex ? Color.white : Color.white.opacity(0.35))
                        .frame(
                            width: index == self.selectedIndex ? (self.isCompact ? 13 : 18) : (self.isCompact ? 4.5 : 6),
                            height: self.isCompact ? 4 : 5
                        )
                        .animation(AppAnimation.smooth, value: self.selectedIndex)
                        .onTapGesture {
                            withAnimation(AppAnimation.smooth) {
                                self.selectedIndex = index
                            }
                        }
                }
            }
            .padding(.horizontal, self.isCompact ? 2 : 4)

            // Next Chevron Button
            Button {
                withAnimation(AppAnimation.smooth) {
                    self.selectedIndex = (self.selectedIndex + 1) % self.heroItems.count
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: self.isCompact ? 9.5 : 11, weight: .bold))
                    .foregroundStyle(self.isHoveringNext ? .white : .white.opacity(0.70))
                    .frame(width: self.isCompact ? 20 : 26, height: self.isCompact ? 20 : 26)
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
        .padding(.horizontal, self.isCompact ? 6 : 8)
        .padding(.vertical, self.isCompact ? 3 : 4)
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

// MARK: - DiagonalSliceShape

struct DiagonalSliceShape: Shape {
    let index: Int
    let sliceCount: Int
    let slant: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard self.sliceCount >= 1 else { return path }

        let totalCount = CGFloat(self.sliceCount)
        let effectiveWidth = rect.width + self.slant
        let sliceWidth = effectiveWidth / totalCount

        let startXTop = CGFloat(self.index) * sliceWidth - self.slant
        let endXTop = CGFloat(self.index + 1) * sliceWidth - self.slant
        let startXBottom = CGFloat(self.index) * sliceWidth
        let endXBottom = CGFloat(self.index + 1) * sliceWidth

        path.move(to: CGPoint(x: startXTop, y: 0))
        path.addLine(to: CGPoint(x: endXTop, y: 0))
        path.addLine(to: CGPoint(x: endXBottom, y: rect.height))
        path.addLine(to: CGPoint(x: startXBottom, y: rect.height))
        path.closeSubpath()

        return path
    }
}

// MARK: - DiagonalSliceDividerShape

struct DiagonalSliceDividerShape: Shape {
    let index: Int
    let sliceCount: Int
    let slant: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard self.sliceCount >= 1 else { return path }

        let totalCount = CGFloat(self.sliceCount)
        let effectiveWidth = rect.width + self.slant
        let sliceWidth = effectiveWidth / totalCount

        let topX = CGFloat(self.index) * sliceWidth - self.slant
        let bottomX = CGFloat(self.index) * sliceWidth

        path.move(to: CGPoint(x: topX, y: 0))
        path.addLine(to: CGPoint(x: bottomX, y: rect.height))

        return path
    }
}
