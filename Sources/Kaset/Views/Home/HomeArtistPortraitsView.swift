//
//  HomeArtistPortraitsView.swift
//  Kaset
//
//  110pt Circular Artist Avatars Carousel.
//

import SwiftUI

// MARK: - HomeArtistPortraitsView

/// 110pt Circular Artist Avatars Carousel with centered name and glass border.
struct HomeArtistPortraitsView: View {
    let title: String
    let artists: [Artist]
    let onNavigateArtist: (Artist) -> Void
    var contentInset: CGFloat = DetailContentLayout.horizontalInset

    var body: some View {
        CarouselShelfSection(
            accessibilityLabel: self.title,
            items: self.artists,
            id: \.id,
            itemAlignment: .top,
            itemSpacing: 20,
            contentInset: self.contentInset
        ) {
            Text(self.title)
                .font(.title2)
                .fontWeight(.semibold)
        } itemContent: { artist in
            HomeArtistAvatarItemView(
                artist: artist,
                onNavigate: { self.onNavigateArtist(artist) }
            )
        }
    }
}

// MARK: - HomeArtistAvatarItemView

private struct HomeArtistAvatarItemView: View {
    let artist: Artist
    let onNavigate: () -> Void

    @State private var isHovering = false

    private static let avatarSize: CGFloat = 110

    var body: some View {
        Button(action: self.onNavigate) {
            VStack(spacing: 8) {
                // Circular Avatar
                ZStack {
                    if let url = self.artist.thumbnailURL?.highQualityThumbnailURL {
                        CachedAsyncImage(
                            url: url,
                            targetSize: CGSize(width: Self.avatarSize, height: Self.avatarSize)
                        ) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 38))
                                        .foregroundStyle(.secondary)
                                }
                        }
                    } else {
                        Circle()
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 38))
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: Self.avatarSize, height: Self.avatarSize)
                .clipShape(.circle)
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.16), lineWidth: 1.5)
                )
                .shadow(
                    color: self.isHovering ? .black.opacity(0.24) : .black.opacity(0.12),
                    radius: self.isHovering ? 12 : 6,
                    x: 0,
                    y: self.isHovering ? 5 : 2
                )

                // Artist Name
                Text(self.artist.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: Self.avatarSize)
            }
            .frame(width: Self.avatarSize)
        }
        .buttonStyle(.plain)
        .scaleEffect(self.isHovering ? 1.04 : 1.0)
        .animation(AppAnimation.spring, value: self.isHovering)
        .onHover { hovering in
            withAnimation(AppAnimation.quick) {
                self.isHovering = hovering
            }
        }
        .accessibilityLabel(String(localized: "Artist: \(self.artist.name)"))
    }
}
