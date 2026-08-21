//
//  HomeActivityBentoView.swift
//  Kaset
//
//  "Jump Back In" recent rotation shelf with compact 150pt cards and Liquid Glass actions.
//

import SwiftUI

// MARK: - HomeActivityBentoView

/// "Jump Back In" Recent Rotation Shelf displaying up to 8 top recent/rotation items.
struct HomeActivityBentoView: View {
    let bentoPayload: HomeBentoItemPayload
    let onPlaySong: (Song) -> Void
    let onPlayItem: (HomeSectionItem) -> Void
    let onNavigateItem: (HomeSectionItem) -> Void
    let onNavigateArtist: (Artist) -> Void
    var onViewMore: (() -> Void)?
    var contentInset: CGFloat = DetailContentLayout.horizontalInset

    var body: some View {
        CarouselShelfSection(
            accessibilityLabel: String(localized: "Jump Back In"),
            items: self.bentoPayload.items,
            id: \.id,
            itemAlignment: .top,
            itemSpacing: 16,
            contentInset: self.contentInset
        ) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.tint)

                Text("Jump Back In")
                    .font(.title2)
                    .fontWeight(.semibold)

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
        } itemContent: { item in
            JumpBackInCardView(
                item: item,
                onCardClick: {
                    switch item {
                    case let .song(song):
                        // Clicking song card plays the song!
                        self.onPlaySong(song)
                    case .album, .playlist, .artist:
                        // Clicking album/playlist/artist opens detail view!
                        self.onNavigateItem(item)
                    }
                },
                onQuickPlay: {
                    self.onPlayItem(item)
                },
                onArtistClick: { artist in
                    self.onNavigateArtist(artist)
                }
            )
        }
    }
}

// MARK: - JumpBackInCardView

private struct JumpBackInCardView: View {
    let item: HomeSectionItem
    let onCardClick: () -> Void
    let onQuickPlay: () -> Void
    let onArtistClick: (Artist) -> Void

    @State private var isHovering = false

    private static let cardWidth: CGFloat = 155
    private static let artworkSize: CGFloat = 155

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
            VStack(alignment: .leading, spacing: 8) {
                // Artwork Box
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
                                    Image(systemName: "music.note")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.secondary)
                                }
                        }
                    } else {
                        Rectangle()
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.secondary)
                            }
                    }

                    // Hover Liquid Glass Play Button (for songs, albums, and playable playlists)
                    if self.isQuickPlayable, self.isHovering {
                        Button(action: self.onQuickPlay) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.primary)
                                .offset(x: 1.5)
                                .frame(width: 42, height: 42)
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
                .shadow(
                    color: self.isHovering ? .black.opacity(0.25) : .black.opacity(0.10),
                    radius: self.isHovering ? 14 : 6,
                    x: 0,
                    y: self.isHovering ? 6 : 2
                )

                // Title & Subtitle
                VStack(alignment: .leading, spacing: 3) {
                    Text(self.item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let subtitle = self.item.homeCardSubtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(width: Self.cardWidth, alignment: .leading)
            }
            .frame(width: Self.cardWidth)
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
    }
}
