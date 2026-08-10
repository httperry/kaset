import SwiftUI

/// Now-Playing Spotlight presentation view draft.
struct NowPlayingSpotlightView: View {
    @Environment(\.dismiss) private var dismiss

    let song: Song?
    let isPlaying: Bool
    let onPlayPause: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button(action: { self.dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding([.top, .trailing])

            Spacer()

            // Artwork Placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.quaternary)
                    .frame(width: 280, height: 280)

                Image(systemName: "music.note")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text(self.song?.title ?? "No Track Playing")
                    .font(.title2.weight(.bold))
                    .lineLimit(1)

                Text(self.song?.artists.map(\.name).joined(separator: ", ") ?? "Unknown Artist")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Button(action: self.onPlayPause) {
                Image(systemName: self.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 54))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding()
        .frame(minWidth: 480, minHeight: 600)
    }
}
