//
//  HomeVideoPerformancesView.swift
//  Kaset
//
//  16:9 Landscape Video Cards Carousel for music videos and live performances.
//

import SwiftUI

// MARK: - HomeVideoPerformancesView

/// 16:9 Landscape Video Cards Carousel with duration badge and play hover overlay.
struct HomeVideoPerformancesView: View {
    let title: String
    let videos: [Song]
    let onPlayVideo: (Song) -> Void
    let onNavigateVideo: (Song) -> Void
    var contentInset: CGFloat = DetailContentLayout.horizontalInset

    var body: some View {
        CarouselShelfSection(
            accessibilityLabel: self.title,
            items: self.videos,
            id: \.id,
            itemAlignment: .top,
            itemSpacing: 16,
            contentInset: self.contentInset
        ) {
            Text(self.title)
                .font(.title2)
                .fontWeight(.semibold)
        } itemContent: { song in
            HomeVideoCardItemView(
                song: song,
                onPlay: { self.onPlayVideo(song) },
                onNavigate: { self.onNavigateVideo(song) }
            )
        }
    }
}

// MARK: - HomeVideoCardItemView

private struct HomeVideoCardItemView: View {
    let song: Song
    let onPlay: () -> Void
    let onNavigate: () -> Void

    @State private var isHovering = false

    private static let cardWidth: CGFloat = 270
    private static let cardHeight: CGFloat = 152

    var body: some View {
        Button(action: self.onPlay) {
            VStack(alignment: .leading, spacing: 8) {
                // 16:9 Video Artwork Box
                ZStack(alignment: .bottomTrailing) {
                    if let url = self.song.wideHighQualityThumbnailURL ?? self.song.thumbnailURL?.highQualityThumbnailURL {
                        CachedAsyncImage(
                            url: url,
                            targetSize: CGSize(width: Self.cardWidth, height: Self.cardHeight)
                        ) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .overlay {
                                    Image(systemName: "play.rectangle")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.secondary)
                                }
                        }
                    } else {
                        Rectangle()
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay {
                                Image(systemName: "play.rectangle")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.secondary)
                            }
                    }

                    // Centered Hover Play Button
                    if self.isHovering {
                        Image(systemName: "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                            .offset(x: 2)
                            .frame(width: 48, height: 48)
                            .compatGlass(interactive: true, in: .circle)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }

                    // Duration Badge (Bottom-Right)
                    if self.song.duration != nil {
                        Text(self.song.durationDisplay)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.75), in: .rect(cornerRadius: 4))
                            .padding(8)
                    }
                }
                .frame(width: Self.cardWidth, height: Self.cardHeight)
                .clipShape(.rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(
                    color: self.isHovering ? .black.opacity(0.24) : .black.opacity(0.10),
                    radius: self.isHovering ? 12 : 6,
                    x: 0,
                    y: self.isHovering ? 4 : 2
                )

                // Title & Subtitle
                VStack(alignment: .leading, spacing: 3) {
                    Text(self.song.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(self.song.artistsDisplay)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
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
        .accessibilityLabel(String(localized: "Video: \(self.song.title) by \(self.song.artistsDisplay)"))
    }
}
