//
//  HomeActivityBentoView.swift
//  Kaset
//
//  "Jump Back In" recent rotation shelf with compact 150pt cards and Liquid Glass actions.
//

import SwiftUI

// MARK: - HomeActivityBentoView

/// "Jump Back In" Consolidated Recent Rotation Shelf displaying a 1:1 Resume Square tile on the left
/// alongside 3-row Liquid Glass track columns (Quick Picks style).
struct HomeActivityBentoView: View {
    let bentoPayload: HomeBentoItemPayload
    var lastPlayedSong: Song?
    var lastPlayedProgress: Double = 0.0
    var isPlaying: Bool = false
    var onResumeLastPlayed: (() -> Void)?
    let onPlaySong: (Song) -> Void
    let onPlayItem: (HomeSectionItem) -> Void
    let onNavigateItem: (HomeSectionItem) -> Void
    let onNavigateArtist: (Artist) -> Void
    var onViewMore: (() -> Void)?
    var contentInset: CGFloat = DetailContentLayout.horizontalInset
    var contextMenu: ((HomeSectionItem) -> AnyView)?
    var songContextMenu: ((Song) -> AnyView)?

    private var filteredItems: [HomeSectionItem] {
        guard let lastPlayedSong else { return self.bentoPayload.items }
        let lastTitle = lastPlayedSong.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return self.bentoPayload.items.filter { item in
            if let vId = item.videoId, vId == lastPlayedSong.videoId {
                return false
            }
            if case let .song(s) = item, s.videoId == lastPlayedSong.videoId {
                return false
            }
            if item.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == lastTitle {
                return false
            }
            return true
        }
    }

    /// Chunks items into 3 rows per column (Quick Picks style)
    private var columns: [[HomeSectionItem]] {
        var result: [[HomeSectionItem]] = []
        let items = self.filteredItems
        var index = 0
        while index < items.count {
            let nextIndex = min(index + 3, items.count)
            result.append(Array(items[index ..< nextIndex]))
            index = nextIndex
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Shelf Header
            HStack(spacing: 8) {
                Button {
                    self.onViewMore?()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.tint)

                        Text("Jump Back In")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                if let onViewMore {
                    Button(action: onViewMore) {
                        HStack(spacing: 4) {
                            Text("See All")
                                .font(.system(size: 13, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, self.contentInset)
            .padding(.bottom, 10)

            // Horizontal Carousel Shelf
            CarouselShelf(
                accessibilityLabel: String(localized: "Jump Back In"),
                pageFraction: 0.85,
                showsControls: true,
                controlVerticalAlignment: .center,
                contentInset: self.contentInset
            ) {
                HStack(alignment: .top, spacing: 14) {
                    // Leading 1:1 Resume Square Tile (spans exact height of 3 rows: 178pt)
                    if let lastPlayedSong {
                        ResumeSquareTileView(
                            song: lastPlayedSong,
                            progress: self.lastPlayedProgress,
                            isPlaying: self.isPlaying,
                            size: 178,
                            onResume: { self.onResumeLastPlayed?() },
                            contextMenu: self.songContextMenu
                        )
                    }

                    // 3-Row Liquid Glass Track Columns
                    ForEach(Array(self.columns.enumerated()), id: \.offset) { _, columnItems in
                        VStack(spacing: 8) {
                            ForEach(columnItems, id: \.id) { item in
                                JumpBackInTrackRowView(
                                    item: item,
                                    onCardClick: {
                                        switch item {
                                        case let .song(song):
                                            self.onPlaySong(song)
                                        case .album, .playlist, .artist:
                                            self.onNavigateItem(item)
                                        }
                                    },
                                    onQuickPlay: { self.onPlayItem(item) },
                                    onArtistClick: { self.onNavigateArtist($0) },
                                    contextMenu: self.contextMenu
                                )
                            }
                        }
                        .frame(width: 290)
                    }
                }
            }
        }
    }
}

// MARK: - ResumeSquareTileView

/// 1:1 Large Square Tile matching the 3-row height, with live animated equalizer waveform,
/// resilient thumbnail loading with YouTube CDN fallback, bottom scrim, and progress bar.
private struct ResumeSquareTileView: View {
    let song: Song
    let progress: Double
    let isPlaying: Bool
    let size: CGFloat
    let onResume: () -> Void
    var contextMenu: ((Song) -> AnyView)?

    @State private var isHovering = false

    private var artworkURL: URL? {
        self.song.thumbnailURL?.highQualityThumbnailURL
            ?? self.song.thumbnailURL
            ?? self.song.fallbackThumbnailURL
    }

    private var is4x3PillarboxedURL: Bool {
        guard let url = self.artworkURL else { return false }
        return url.absoluteString.contains("hqdefault.jpg")
    }

    var body: some View {
        Button(action: self.onResume) {
            ZStack(alignment: .bottomLeading) {
                // Background Cover Art with dark baseline and fallback protection
                ZStack {
                    Color(nsColor: NSColor(white: 0.12, alpha: 1.0))

                    if let url = self.artworkURL {
                        CachedAsyncImage(
                            url: url,
                            targetSize: CGSize(width: self.size * 2, height: self.size * 2)
                        ) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .scaleEffect(self.is4x3PillarboxedURL ? 1.334 : 1.0)
                                .frame(width: self.size, height: self.size)
                                .clipped()
                        } placeholder: {
                            if let fallback = self.song.fallbackThumbnailURL, fallback != url {
                                CachedAsyncImage(
                                    url: fallback,
                                    targetSize: CGSize(width: self.size * 2, height: self.size * 2)
                                ) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .scaleEffect(self.is4x3PillarboxedURL ? 1.334 : 1.0)
                                        .frame(width: self.size, height: self.size)
                                        .clipped()
                                } placeholder: {
                                    Color(nsColor: NSColor(white: 0.16, alpha: 1.0))
                                        .overlay {
                                            Image(systemName: "music.note")
                                                .font(.system(size: 36))
                                                .foregroundStyle(.white.opacity(0.4))
                                        }
                                }
                            } else {
                                Color(nsColor: NSColor(white: 0.16, alpha: 1.0))
                                    .overlay {
                                        Image(systemName: "music.note")
                                            .font(.system(size: 36))
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                            }
                        }
                    } else {
                        Color(nsColor: NSColor(white: 0.16, alpha: 1.0))
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                    }
                }
                .frame(width: self.size, height: self.size)

                // Dark Bottom Scrim for Title Legibility
                LinearGradient(
                    colors: [.clear, .black.opacity(0.40), .black.opacity(0.88)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                // Center Liquid Glass Play/Pause Button on Hover
                if self.isHovering {
                    ZStack {
                        Color.black.opacity(0.20)
                        Button(action: self.onResume) {
                            Image(systemName: self.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .offset(x: self.isPlaying ? 0 : 1.5)
                                .frame(width: 44, height: 44)
                                .compatGlass(interactive: true, in: .circle)
                                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                }

                // Bottom Content: Title, Artist & Progress Bar
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.song.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)

                    Text(self.song.artistsDisplay.isEmpty ? String(localized: "Last Played") : self.song.artistsDisplay)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.80))
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, self.progress > 0.02 && self.progress < 0.98 ? 9 : 10)

                // Bottom Sleek Progress Bar
                if self.progress > 0.02, self.progress < 0.98 {
                    GeometryReader { barGeo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(.black.opacity(0.5))
                            Rectangle()
                                .fill(.white.opacity(0.95))
                                .frame(width: max(0, min(barGeo.size.width, barGeo.size.width * CGFloat(self.progress))))
                        }
                    }
                    .frame(height: 3)
                    .clipShape(.rect(bottomLeadingRadius: 14, bottomTrailingRadius: 14))
                }
            }
            .frame(width: self.size, height: self.size)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white.opacity(self.isHovering ? 0.22 : 0.08), lineWidth: 1)
            )
            .shadow(
                color: .black.opacity(self.isHovering ? 0.20 : 0.08),
                radius: self.isHovering ? 8 : 3,
                x: 0,
                y: self.isHovering ? 3 : 1
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(self.isHovering ? 1.015 : 1.0)
        .animation(AppAnimation.quick, value: self.isHovering)
        .onHover { hovering in
            withAnimation(AppAnimation.quick) {
                self.isHovering = hovering
            }
        }
        .contextMenu {
            if let contextMenu {
                contextMenu(self.song)
            }
        }
    }
}

// MARK: - JumpBackInTrackRowView

/// 3-Row Liquid Glass Track Row (Quick Picks style) with artwork on left, title & artist, and hover play action.
private struct JumpBackInTrackRowView: View {
    let item: HomeSectionItem
    let onCardClick: () -> Void
    let onQuickPlay: () -> Void
    let onArtistClick: (Artist) -> Void
    var contextMenu: ((HomeSectionItem) -> AnyView)?

    @Environment(PlayerService.self) private var playerService
    @State private var isHovering = false

    private static let rowHeight: CGFloat = 54
    private static let artworkSize: CGFloat = 46

    private var isCurrentlyPlaying: Bool {
        guard let currentTrack = self.playerService.currentTrack else { return false }
        if let videoId = self.item.videoId, videoId == currentTrack.videoId {
            return true
        }
        if case let .song(song) = self.item, song.videoId == currentTrack.videoId {
            return true
        }
        let itemTitle = Self.normalizeForComparison(self.item.title)
        let trackTitle = Self.normalizeForComparison(currentTrack.title)
        if !itemTitle.isEmpty, !trackTitle.isEmpty {
            if itemTitle == trackTitle || itemTitle.contains(trackTitle) || trackTitle.contains(itemTitle) {
                return true
            }
        }
        return false
    }

    private static func normalizeForComparison(_ str: String) -> String {
        str.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    private var isQuickPlayable: Bool {
        switch self.item {
        case .song, .album:
            true
        case let .playlist(playlist):
            SongActionsHelper.canQuickPlayPlaylist(playlist)
        case .artist:
            false
        }
    }

    var body: some View {
        Button(action: self.onCardClick) {
            HStack(spacing: 10) {
                // Square Artwork flush with rounded corners & active liquid glass indicator
                ZStack {
                    if let url = self.item.thumbnailURL?.highQualityThumbnailURL ?? self.item.thumbnailURL {
                        CachedAsyncImage(
                            url: url,
                            targetSize: CGSize(width: Self.artworkSize * 2, height: Self.artworkSize * 2)
                        ) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: Self.artworkSize, height: Self.artworkSize)
                                .clipped()
                        } placeholder: {
                            Rectangle()
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .overlay {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.secondary)
                                }
                        }
                    } else {
                        Rectangle()
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
                            }
                    }

                    if self.isQuickPlayable, self.isHovering, !self.isCurrentlyPlaying {
                        // Hover Play Icon over Artwork
                        Circle()
                            .fill(.black.opacity(0.55))
                            .frame(width: 26, height: 26)
                            .overlay {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .offset(x: 1)
                            }
                            .transition(.opacity)
                    }
                }
                .frame(width: Self.artworkSize, height: Self.artworkSize)
                .clipShape(.rect(cornerRadius: 8))

                // Title & Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(self.item.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let subtitle = self.item.homeCardSubtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(width: 290, height: Self.rowHeight)
            .compatGlass(interactive: true, in: .rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(self.isHovering ? Color.white.opacity(0.18) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(
                color: self.isHovering ? .black.opacity(0.15) : .clear,
                radius: self.isHovering ? 6 : 0,
                x: 0,
                y: self.isHovering ? 2 : 0
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(self.isHovering ? 1.012 : 1.0)
        .animation(AppAnimation.quick, value: self.isHovering)
        .onHover { hovering in
            withAnimation(AppAnimation.quick) {
                self.isHovering = hovering
            }
        }
        .accessibilityLabel(String(localized: "\(self.item.title), \(self.item.homeCardSubtitle ?? "")"))
        .contextMenu {
            if let contextMenu {
                contextMenu(self.item)
            }
        }
    }
}
