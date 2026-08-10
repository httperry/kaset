import SwiftUI

/// Now-Playing Spotlight presentation view with ambient artwork glow, modular controls, and side drawer.
struct NowPlayingSpotlightView: View {
    @Environment(\.dismiss) private var dismiss

    let song: Song?
    let isPlaying: Bool
    let progress: TimeInterval
    let duration: TimeInterval
    let volume: Double
    let isMuted: Bool
    let queueSongs: [Song]
    let lyricsText: String?
    let onPlayPause: () -> Void
    let onSeek: (TimeInterval) -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onVolumeChange: (Double) -> Void
    let onToggleMute: () -> Void
    let onAirPlay: () -> Void

    @State private var isDrawerVisible = false
    @State private var selectedDrawerTab: SpotlightSideDrawer.Tab = .lyrics

    var body: some View {
        ZStack {
            // Ambient Backdrop Glow
            if let artworkURL = self.song?.thumbnailURL {
                PlayerBarArtworkGlow(
                    sources: [artworkURL],
                    identity: self.song?.id,
                    targetSize: CGSize(width: 600, height: 600),
                    width: 750,
                    height: 750,
                    cornerRadius: 32
                )
                .opacity(0.70)
            }

            VStack(spacing: 0) {
                // Header Bar
                SpotlightHeaderView(
                    onDismiss: { self.dismiss() },
                    onAirPlay: self.onAirPlay
                )

                Spacer(minLength: 16)

                // Main Content Body (Artwork + Metadata + Controls & Side Drawer)
                HStack(spacing: 32) {
                    VStack(spacing: 24) {
                        // Spotlight Album Artwork
                        ZStack {
                            if let artworkURL = self.song?.thumbnailURL {
                                CachedAsyncImage(url: artworkURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 280, height: 280)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: .black.opacity(0.40), radius: 24, x: 0, y: 12)
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(.quaternary)
                                        .frame(width: 280, height: 280)

                                    Image(systemName: "music.note")
                                        .font(.system(size: 80))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Track Metadata Titles
                        VStack(spacing: 6) {
                            Text(self.song?.title ?? "No Track Playing")
                                .font(.system(size: 24, weight: .bold))
                                .lineLimit(1)

                            Text(self.song?.artists.map(\.name).joined(separator: ", ") ?? "Unknown Artist")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            if let albumTitle = self.song?.album?.title {
                                Text(albumTitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 24)

                        // Interactive Media Controls Section
                        SpotlightControlsSection(
                            isPlaying: self.isPlaying,
                            progress: self.progress,
                            duration: self.duration,
                            volume: self.volume,
                            isMuted: self.isMuted,
                            onPlayPause: self.onPlayPause,
                            onSeek: self.onSeek,
                            onNext: self.onNext,
                            onPrevious: self.onPrevious,
                            onVolumeChange: self.onVolumeChange,
                            onToggleMute: self.onToggleMute
                        )
                    }

                    // Side Drawer for Lyrics / Queue
                    SpotlightSideDrawer(
                        selectedTab: self.$selectedDrawerTab,
                        isVisible: self.isDrawerVisible,
                        lyricsText: self.lyricsText,
                        queueSongs: self.queueSongs
                    )
                }

                Spacer(minLength: 16)

                // Footer Drawer Toggle Toolbar
                HStack(spacing: 20) {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if self.isDrawerVisible && self.selectedDrawerTab == .lyrics {
                                self.isDrawerVisible = false
                            } else {
                                self.selectedDrawerTab = .lyrics
                                self.isDrawerVisible = true
                            }
                        }
                    }) {
                        Label("Lyrics", systemImage: "quote.bubble.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(self.isDrawerVisible && self.selectedDrawerTab == .lyrics ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if self.isDrawerVisible && self.selectedDrawerTab == .queue {
                                self.isDrawerVisible = false
                            } else {
                                self.selectedDrawerTab = .queue
                                self.isDrawerVisible = true
                            }
                        }
                    }) {
                        Label("Queue (\(self.queueSongs.count))", systemImage: "list.bullet.rectangle.portrait.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(self.isDrawerVisible && self.selectedDrawerTab == .queue ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 20)
            }
        }
        .frame(minWidth: 640, minHeight: 720)
    }
}
