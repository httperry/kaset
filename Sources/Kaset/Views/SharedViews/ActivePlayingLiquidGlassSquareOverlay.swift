import SwiftUI

// MARK: - EqualizerWaveformView

/// Animated audio equalizer waveform with 4 vertical bars dynamically resizing.
struct EqualizerWaveformView: View {
    let isPlaying: Bool
    var color: Color = .white
    var barWidth: CGFloat = 2.0
    var maxHeight: CGFloat = 11

    @State private var phase = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.8) {
            WaveformBar(heightFraction: self.isPlaying ? (self.phase ? 0.95 : 0.25) : 0.35, color: self.color, width: self.barWidth, maxHeight: self.maxHeight)
                .animation(self.isPlaying ? .easeInOut(duration: 0.42).repeatForever(autoreverses: true) : .default, value: self.phase)
            WaveformBar(heightFraction: self.isPlaying ? (self.phase ? 0.30 : 1.0) : 0.65, color: self.color, width: self.barWidth, maxHeight: self.maxHeight)
                .animation(self.isPlaying ? .easeInOut(duration: 0.35).repeatForever(autoreverses: true).delay(0.08) : .default, value: self.phase)
            WaveformBar(heightFraction: self.isPlaying ? (self.phase ? 1.0 : 0.40) : 0.85, color: self.color, width: self.barWidth, maxHeight: self.maxHeight)
                .animation(self.isPlaying ? .easeInOut(duration: 0.50).repeatForever(autoreverses: true).delay(0.16) : .default, value: self.phase)
            WaveformBar(heightFraction: self.isPlaying ? (self.phase ? 0.25 : 0.80) : 0.45, color: self.color, width: self.barWidth, maxHeight: self.maxHeight)
                .animation(self.isPlaying ? .easeInOut(duration: 0.38).repeatForever(autoreverses: true).delay(0.12) : .default, value: self.phase)
        }
        .frame(height: self.maxHeight)
        .onAppear {
            if self.isPlaying {
                self.phase = true
            }
        }
        .onChange(of: self.isPlaying) { _, playing in
            self.phase = playing
        }
    }
}

// MARK: - WaveformBar

private struct WaveformBar: View {
    let heightFraction: CGFloat
    let color: Color
    let width: CGFloat
    let maxHeight: CGFloat

    var body: some View {
        Capsule()
            .fill(self.color)
            .frame(width: self.width, height: max(2.5, self.maxHeight * self.heightFraction))
    }
}

// MARK: - ActivePlayingLiquidGlassFrame

/// A macOS Liquid Glass frame around selected / currently playing 1:1 square grid cards,
/// wrapping both the artwork and song content inside a crystal-clear Liquid Glass card platter.
struct ActivePlayingLiquidGlassFrame: ViewModifier {
    let isSelected: Bool
    var cornerRadius: CGFloat = 16
    var extraPadding: CGFloat = 0
    var tintColor: Color?

    func body(content: Content) -> some View {
        if self.isSelected {
            content
                .clipShape(.rect(cornerRadius: self.cornerRadius, style: .continuous))
                // Clear Liquid Glass card platter containing the whole card
                .background {
                    RoundedRectangle(cornerRadius: self.cornerRadius + self.extraPadding, style: .continuous)
                        .compatGlass(
                            interactive: false,
                            tint: self.tintColor,
                            in: .rect(cornerRadius: self.cornerRadius + self.extraPadding, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: self.cornerRadius + self.extraPadding, style: .continuous)
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
                                    lineWidth: 1.3
                                )
                        )
                        .padding(-self.extraPadding)
                        .shadow(color: .black.opacity(0.20), radius: 8, x: 0, y: 3)
                }
                .transition(.scale(scale: 0.97).combined(with: .opacity))
        } else {
            content
        }
    }
}

extension View {
    func activePlayingLiquidGlassFrame(
        isSelected: Bool,
        cornerRadius: CGFloat = 16,
        extraPadding: CGFloat = 0,
        tintColor: Color? = nil
    ) -> some View {
        self.modifier(ActivePlayingLiquidGlassFrame(
            isSelected: isSelected,
            cornerRadius: cornerRadius,
            extraPadding: extraPadding,
            tintColor: tintColor
        ))
    }
}

// MARK: - GoogleMeetAudioVisualizerBadge

/// A Google Meet / Siri-style 3-dot vertical audio visualizer inside a frosted Liquid Glass circular badge,
/// positioned in the top-left corner of the playing artwork.
struct GoogleMeetAudioVisualizerBadge: View {
    let isPlaying: Bool
    var barWidth: CGFloat = 2.4
    var maxHeight: CGFloat = 13
    var minHeight: CGFloat = 3.5
    var color: Color = .white

    @State private var phase1 = false
    @State private var phase2 = false
    @State private var phase3 = false

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            // Dot/Bar 1
            Capsule()
                .fill(self.color)
                .frame(
                    width: self.barWidth,
                    height: self.isPlaying ? (self.phase1 ? self.maxHeight * 0.90 : self.minHeight) : self.minHeight
                )
                .animation(
                    self.isPlaying
                        ? .easeInOut(duration: 0.42).repeatForever(autoreverses: true)
                        : .default,
                    value: self.phase1
                )

            // Dot/Bar 2 (Center - taller)
            Capsule()
                .fill(self.color)
                .frame(
                    width: self.barWidth,
                    height: self.isPlaying ? (self.phase2 ? self.maxHeight : self.minHeight * 1.2) : self.minHeight
                )
                .animation(
                    self.isPlaying
                        ? .easeInOut(duration: 0.52).repeatForever(autoreverses: true).delay(0.10)
                        : .default,
                    value: self.phase2
                )

            // Dot/Bar 3
            Capsule()
                .fill(self.color)
                .frame(
                    width: self.barWidth,
                    height: self.isPlaying ? (self.phase3 ? self.maxHeight * 0.78 : self.minHeight) : self.minHeight
                )
                .animation(
                    self.isPlaying
                        ? .easeInOut(duration: 0.38).repeatForever(autoreverses: true).delay(0.20)
                        : .default,
                    value: self.phase3
                )
        }
        .frame(width: 26, height: 26)
        .background {
            Circle()
                .fill(.black.opacity(0.45))
                .compatGlass(interactive: false, in: .circle)
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.65),
                                    .white.opacity(0.20),
                                    .white.opacity(0.05),
                                    .white.opacity(0.40),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)
        }
        .onAppear {
            if self.isPlaying {
                self.phase1 = true
                self.phase2 = true
                self.phase3 = true
            }
        }
        .onChange(of: self.isPlaying) { _, playing in
            self.phase1 = playing
            self.phase2 = playing
            self.phase3 = playing
        }
    }
}

// MARK: - ActivePlayingArtworkBadgeOverlay

/// Top-left Google Meet-style audio visualizer badge for active playing song artwork.
struct ActivePlayingArtworkBadgeOverlay: View {
    let isPlaying: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            GoogleMeetAudioVisualizerBadge(isPlaying: self.isPlaying)
                .padding(7)
        }
        .allowsHitTesting(false)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}
