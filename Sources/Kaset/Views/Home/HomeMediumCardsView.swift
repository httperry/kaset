//
//  HomeMediumCardsView.swift
//  Kaset
//
//  175pt Medium Glow Cards Carousel for albums, playlists, and mixes.
//

import SwiftUI

// MARK: - HomeMediumCardsView

/// 175pt Medium Card Carousel with ambient shadow and Liquid Glass play hover overlay.
struct HomeMediumCardsView: View {
    let title: String
    let items: [HomeSectionItem]
    let onPlayItem: (HomeSectionItem) -> Void
    let onNavigateItem: (HomeSectionItem) -> Void
    var contentInset: CGFloat = DetailContentLayout.horizontalInset

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
                onNavigate: { self.onNavigateItem(item) }
            )
        }
    }
}

// MARK: - HomeMediumCardItemView

private struct HomeMediumCardItemView: View {
    let item: HomeSectionItem
    let onPlay: () -> Void
    let onNavigate: () -> Void

    @State private var isHovering = false

    private static let cardWidth: CGFloat = 175
    private static let artworkSize: CGFloat = 175

    var body: some View {
        Button(action: self.onNavigate) {
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

                    // Hover Liquid Glass Play Button
                    if self.isHovering {
                        Button(action: self.onPlay) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.primary)
                                .offset(x: 1.5)
                                .frame(width: 44, height: 44)
                                .compatGlass(interactive: true, in: .circle)
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 3)
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
                    color: self.isHovering ? .black.opacity(0.24) : .black.opacity(0.12),
                    radius: self.isHovering ? 14 : 8,
                    x: 0,
                    y: self.isHovering ? 6 : 3
                )

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

    private var placeholderIcon: String {
        switch self.item {
        case .song: "music.note"
        case .album: "square.stack"
        case .playlist: "music.note.list"
        case .artist: "person.fill"
        }
    }
}
