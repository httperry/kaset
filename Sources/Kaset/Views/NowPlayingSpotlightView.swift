import SwiftUI

/// Now-Playing Spotlight presentation view with ambient artwork glow and interactive controls.
struct NowPlayingSpotlightView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let song: Song?
    let isPlaying: Bool
    let progress: TimeInterval
    let duration: TimeInterval
    let onPlayPause: () -> Void
    let onSeek: (TimeInterval) -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void

    @State private var isHoveringControls = false

    var body: some View {
        ZStack {
            // Ambient Backdrop Glow
            if let artworkURL = self.song?.thumbnailURL {
                PlayerBarArtworkGlow(
                    sources: [artworkURL],
                    identity: self.song?.id,
                    targetSize: CGSize(width: 600, height: 600),
                    width: 700,
                    height: 700,
                    cornerRadius: 32
                )
                .opacity(0.65)
            }

            VStack(spacing: 28) {
                // Header dismiss button
                HStack {
                    Spacer()
                    Button(action: { self.dismiss() }) {
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding([.top, .trailing], 24)

                Spacer()

                // Large Spotlight Album Artwork with Glow Frame
                ZStack {
                    if let artworkURL = self.song?.thumbnailURL {
                        CachedAsyncImage(url: artworkURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 320, height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 12)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.quaternary)
                                .frame(width: 320, height: 320)

                            Image(systemName: "music.note")
                                .font(.system(size: 80))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Track Metadata Info
                VStack(spacing: 8) {
                    Text(self.song?.title ?? "No Track Playing")
                        .font(.system(size: 26, weight: .bold))
                        .lineLimit(1)
                        .multilineTextAlignment(.center)

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
                .padding(.horizontal, 32)

                // Scrubber Progress Lane
                VStack(spacing: 6) {
                    Slider(
                        value: Binding(
                            get: { self.progress },
                            set: { newValue in self.onSeek(newValue) }
                        ),
                        in: 0...max(1, self.duration)
                    )
                    .tint(.primary)

                    HStack {
                        Text(Self.formatTime(self.progress))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("-" + Self.formatTime(max(0, self.duration - self.progress)))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 48)

                // Interactive Media Controls Bar
                HStack(spacing: 40) {
                    Button(action: self.onPrevious) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 24))
                    }
                    .buttonStyle(.plain)

                    Button(action: self.onPlayPause) {
                        Image(systemName: self.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                    }
                    .buttonStyle(.plain)

                    Button(action: self.onNext) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 24))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 32)

                Spacer()
            }
        }
        .frame(minWidth: 540, minHeight: 680)
    }

    private static func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && !time.isNaN else { return "0:00" }
        let totalSeconds = Int(max(0, time))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
