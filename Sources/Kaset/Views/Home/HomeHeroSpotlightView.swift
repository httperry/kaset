//
//  HomeHeroSpotlightView.swift
//  Kaset
//
//  Cinematic 330pt Hero Spotlight Banner with dynamic ambient glow and Liquid Glass actions.
//

import SwiftUI

// MARK: - HomeHeroSpotlightView

/// Full-width cinematic Hero banner displayed at the top of the Home screen.
struct HomeHeroSpotlightView: View {
    let heroItem: HomeHeroItemPayload
    let onPlay: () -> Void
    let onNavigate: () -> Void

    @State private var palette: ColorExtractor.ColorPalette = .default
    @State private var isHovering = false

    private static let bannerHeight: CGFloat = 330
    private static let artworkSize: CGFloat = 190

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Layer 1: Ambient mesh & gradient background
            self.backgroundMeshLayer

            // Layer 2: Dynamic radial glow orb behind artwork
            self.glowOrbLayer

            // Layer 3: Dark bottom vignette for crisp text contrast
            self.vignetteLayer

            // Layer 4: Foreground Hero Content
            HStack(alignment: .bottom, spacing: 28) {
                // Left Artwork Box
                self.artworkView

                // Right Details & Actions
                self.detailsView

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.bannerHeight)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .contentShape(.rect(cornerRadius: 20))
        .onHover { hovering in
            withAnimation(AppAnimation.quick) {
                self.isHovering = hovering
            }
        }
        .task(id: self.heroItem.thumbnailURL) {
            if let url = self.heroItem.thumbnailURL {
                self.palette = await ColorExtractor.cachedPalette(for: url)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Featured: \(self.heroItem.title) by \(self.heroItem.artistSubtitle)"))
    }

    // MARK: - Background Layers

    private var backgroundMeshLayer: some View {
        ZStack {
            // Dark base
            Color(nsColor: NSColor(white: 0.08, alpha: 1.0))

            // Dynamic ambient gradient mesh from extracted album colors
            LinearGradient(
                colors: [
                    self.palette.primary.opacity(0.45),
                    self.palette.secondary.opacity(0.30),
                    Color(nsColor: NSColor(white: 0.05, alpha: 1.0)),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var glowOrbLayer: some View {
        Circle()
            .fill(self.palette.primary)
            .frame(width: 260, height: 260)
            .blur(radius: 55)
            .opacity(0.45)
            .offset(x: 10, y: 30)
            .allowsHitTesting(false)
    }

    private var vignetteLayer: some View {
        LinearGradient(
            colors: [
                .clear,
                .black.opacity(0.20),
                .black.opacity(0.70),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    // MARK: - Artwork

    private var artworkView: some View {
        Button(action: self.onNavigate) {
            ZStack {
                if let url = self.heroItem.thumbnailURL {
                    CachedAsyncImage(
                        url: url,
                        targetSize: CGSize(width: Self.artworkSize, height: Self.artworkSize)
                    ) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(self.palette.primary.opacity(0.3))
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                    }
                } else {
                    Rectangle()
                        .fill(self.palette.primary.opacity(0.3))
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 44))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                }
            }
            .frame(width: Self.artworkSize, height: Self.artworkSize)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: self.palette.primary.opacity(0.50), radius: 36, x: 0, y: 12)
            .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Details & Actions

    private var detailsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Badge (if present)
            if let badgeText = self.heroItem.badgeText, !badgeText.isEmpty {
                Text(badgeText)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .tracking(0.6)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .compatGlass(interactive: false, in: .capsule)
            }

            // Title
            Button(action: self.onNavigate) {
                Text(self.heroItem.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            // Artist Subtitle
            Text(self.heroItem.artistSubtitle)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)

            // Contextual Editorial Description
            if let editorial = self.heroItem.editorialDescription, !editorial.isEmpty {
                Text(editorial)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.60))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
                .frame(height: 6)

            // Action Row
            HStack(spacing: 12) {
                // Primary Action Button (Start Listening)
                Button(action: self.onPlay) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Start Listening")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .compatGlassProminentButton()
                .tint(.white)
                .foregroundStyle(.black)
                .accessibilityLabel(String(localized: "Start listening to \(self.heroItem.title)"))

                // Secondary Action Button (View Details)
                Button(action: self.onNavigate) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                        Text("View Details")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .compatGlass(interactive: true, in: .capsule)
            }
        }
    }
}
