//
//  HomeTrackColumnsView.swift
//  Kaset
//
//  3-Row Compact Track Stacks Carousel for audio songs (Quick picks, Remixes, etc.).
//

import SwiftUI

// MARK: - HomeTrackColumnsView

/// 3-Row Compact Track Stacks displaying 12+ playable songs at a glance.
struct HomeTrackColumnsView: View {
    let title: String
    let songs: [Song]
    let onPlaySong: (Song) -> Void
    let onNavigateSong: (Song) -> Void
    var contentInset: CGFloat = DetailContentLayout.horizontalInset
    var contextMenu: ((Song) -> AnyView)?

    @Environment(AuthService.self) private var authService

    private var columns: [[Song]] {
        var chunks: [[Song]] = []
        var currentIndex = 0
        while currentIndex < self.songs.count {
            let nextIndex = min(currentIndex + 3, self.songs.count)
            chunks.append(Array(self.songs[currentIndex ..< nextIndex]))
            currentIndex = nextIndex
        }
        return chunks
    }

    var body: some View {
        CarouselShelfSection(
            accessibilityLabel: self.title,
            items: Array(self.columns.enumerated()),
            id: \.offset,
            itemAlignment: .top,
            itemSpacing: 18,
            contentInset: self.contentInset
        ) {
            Text(self.title)
                .font(.title2)
                .fontWeight(.semibold)
        } itemContent: { _, columnSongs in
            VStack(spacing: 6) {
                ForEach(columnSongs) { song in
                    self.songRow(song)
                }
            }
            .frame(width: 310)
        }
    }

    // MARK: - Song Row

    private func songRow(_ song: Song) -> some View {
        HomeTrackRowView(
            song: song,
            onPlay: { self.onPlaySong(song) },
            onNavigate: { self.onNavigateSong(song) },
            allowsActions: self.authService.hasPersonalAccount,
            contextMenu: self.contextMenu
        )
    }
}

// MARK: - HomeTrackRowView

private struct HomeTrackRowView: View {
    let song: Song
    let onPlay: () -> Void
    let onNavigate: () -> Void
    let allowsActions: Bool
    var contextMenu: ((Song) -> AnyView)?

    @Environment(PlayerService.self) private var playerService
    @State private var isHovering = false

    private var isCurrentlyPlaying: Bool {
        guard let currentTrack = self.playerService.currentTrack else { return false }
        if self.song.videoId == currentTrack.videoId {
            return true
        }
        let itemTitle = Self.normalizeForComparison(self.song.title)
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

    var body: some View {
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
            HStack(spacing: 12) {
                // Thumbnail with Play Hover Overlay
                SongThumbnailView(song: self.song, size: 44, cornerRadius: 6)
                    .overlay {
                        if self.isHovering, !self.isCurrentlyPlaying {
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

                // Song Title & Artist Subtitle
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(self.song.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if self.song.isExplicit == true {
                            ExplicitBadge()
                        }
                    }

                    Text(self.song.artistsDisplay)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                // Like Heart on Hover
                LikeButton(song: self.song, isRowHovered: self.isHovering, allowsActions: self.allowsActions)

                // Duration Text (if available)
                if self.song.duration != nil {
                    Text(self.song.durationDisplay)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(.rect(cornerRadius: 8))
            .background {
                if self.isHovering {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        .compatGlass(interactive: true, in: .rect(cornerRadius: 8))
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let contextMenu {
                contextMenu(self.song)
            }
        }
        .onHover { hovering in
            withAnimation(AppAnimation.quick) {
                self.isHovering = hovering
            }
        }
    }
}
