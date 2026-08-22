//
//  HomeMediumCardsView.swift
//  Kaset
//
//  175pt Medium Glow Cards Carousel for albums, playlists, and mixes.
//

import SwiftUI

// MARK: - HomeMediumCardsView

/// 175pt Medium Card Carousel with ambient shadow and contextual Liquid Glass play hover overlay.
struct HomeMediumCardsView: View {
    let title: String
    let items: [HomeSectionItem]
    let onPlayItem: (HomeSectionItem) -> Void
    let onNavigateItem: (HomeSectionItem) -> Void
    var contentInset: CGFloat = DetailContentLayout.horizontalInset
    var contextMenu: ((HomeSectionItem) -> AnyView)?

    var body: some View {
        CarouselShelfSection(
            accessibilityLabel: self.title,
            items: self.items,
            id: \.id,
            itemAlignment: .top,
            itemSpacing: 16,
            contentInset: self.contentInset
        ) {
            Text(self.title)
                .font(.title2)
                .fontWeight(.semibold)
        } itemContent: { item in
            HomeMediumCardItemView(
                item: item,
                onPlay: { self.onPlayItem(item) },
                onNavigate: { self.onNavigateItem(item) },
                contextMenu: self.contextMenu
            )
        }
    }
}

// MARK: - HomeMediumCardItemView

private struct HomeMediumCardItemView: View {
    let item: HomeSectionItem
    let onPlay: () -> Void
    let onNavigate: () -> Void
    var contextMenu: ((HomeSectionItem) -> AnyView)?

    @Environment(PlayerService.self) private var playerService
    @State private var isHovering = false

    private static let cardWidth: CGFloat = 175
    private static let artworkSize: CGFloat = 175

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
        case .song:
            true
        case .album:
            true
        case let .playlist(playlist):
            SongActionsHelper.canQuickPlayPlaylist(playlist)
        case .artist:
            false
        }
    }

    var body: some View {
        Button {
            switch self.item {
            case .song:
                if self.isCurrentlyPlaying {
                    Task {
                        await self.playerService.seek(to: 0)
                        await self.playerService.resume()
                    }
                } else {
                    self.onPlay()
                }
            case .album, .playlist, .artist:
                self.onNavigate()
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // 175x175 Artwork Box
                ZStack {
                    if let url = self.item.thumbnailURL?.highQualityThumbnailURL {
                        CachedAsyncImage(
                            url: url,
                            targetSize: CGSize(width: Self.artworkSize, height: Self.artworkSize)
                        ) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .overlay {
                                    Image(systemName: self.placeholderIcon)
                                        .font(.system(size: 36))
                                        .foregroundStyle(.secondary)
                                }
                        }
                    } else {
                        Rectangle()
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay {
                                Image(systemName: self.placeholderIcon)
                                    .font(.system(size: 36))
                                    .foregroundStyle(.secondary)
                            }
                    }

                    // Hover Liquid Glass Play Button (only for playable items)
                    if self.isQuickPlayable, self.isHovering {
                        Button {
                            if self.isCurrentlyPlaying {
                                Task {
                                    await self.playerService.seek(to: 0)
                                    await self.playerService.resume()
                                }
                            } else {
                                self.onPlay()
                            }
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.primary)
                                .offset(x: 1.5)
                                .frame(width: 44, height: 44)
                                .compatGlass(interactive: true, in: .circle)
                                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                }
                .frame(width: Self.artworkSize, height: Self.artworkSize)
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
                .overlay {
                    if self.isCurrentlyPlaying {
                        ActivePlayingArtworkBadgeOverlay(
                            isPlaying: self.playerService.isPlaying
                        )
                    }
                }

                // Title & Subtitle
                VStack(alignment: .leading, spacing: 3) {
                    Text(self.item.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let subtitle = self.item.homeCardSubtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(width: Self.cardWidth, alignment: .leading)
            }
            .padding(6)
            .background {
                if self.isCurrentlyPlaying {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .compatGlass(
                            interactive: false,
                            in: .rect(cornerRadius: 16, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.85),
                                            .white.opacity(0.35),
                                            .white.opacity(0.10),
                                            .white.opacity(0.60),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.2
                                )
                        )
                        .shadow(color: .black.opacity(0.20), radius: 6, x: 0, y: 2)
                }
            }
            .frame(width: Self.cardWidth + 12)
            .shadow(
                color: self.isHovering ? .black.opacity(0.24) : .black.opacity(0.10),
                radius: self.isHovering ? 14 : 6,
                x: 0,
                y: self.isHovering ? 6 : 2
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(self.isHovering ? 1.02 : 1.0)
        .animation(AppAnimation.spring, value: self.isHovering)
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

    private var placeholderIcon: String {
        switch self.item {
        case .song: "music.note"
        case .album: "square.stack"
        case .playlist: "music.note.list"
        case .artist: "person.fill"
        }
    }
}
