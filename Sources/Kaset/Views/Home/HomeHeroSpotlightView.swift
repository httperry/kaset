//
//  HomeHeroSpotlightView.swift
//  Kaset
//
//  Cinematic 370pt Hero Spotlight Banner with dynamic ambient blurred backdrop,
//  multi-stop color mesh, glowing 205pt artwork, and Liquid Glass actions.
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

    private static let bannerHeight: CGFloat = 370
    private static let artworkSize: CGFloat = 205

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Layer 1: Blurred high-res artwork backdrop
            self.artworkBackdropLayer

            // Layer 2: Dynamic ambient color mesh & radial glow orbs
            self.colorMeshLayer

            // Layer 3: Right-hand ambient decorative depth (glowing glass aura)
            self.rightHandDecorativeAura

            // Layer 4: Dark bottom and leading vignettes for crisp contrast
            self.vignetteLayer

            // Layer 5: Foreground Hero Content
            HStack(alignment: .bottom, spacing: 32) {
                // Left Artwork Box
                self.artworkView

                // Right Details & Action Buttons
                self.detailsView

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.bannerHeight)
        .clipShape(.rect(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
        .contentShape(.rect(cornerRadius: 24))
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

    private var artworkBackdropLayer: some View {
        ZStack {
            // Dark base background
            Color(nsColor: NSColor(white: 0.07, alpha: 1.0))

            if let url = self.heroItem.thumbnailURL {
                CachedAsyncImage(
                    url: url,
                    targetSize: CGSize(width: 480, height: 480)
                ) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(1.3)
                        .blur(radius: 65)
                        .opacity(0.40)
                } placeholder: {
                    EmptyView()
                }
            }
        }
    }

    private var colorMeshLayer: some View {
        ZStack {
            // Diagonal gradient mesh
            LinearGradient(
                colors: [
                    self.palette.primary.opacity(0.60),
                    self.palette.secondary.opacity(0.35),
                    Color(nsColor: NSColor(white: 0.04, alpha: 0.95)),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Dynamic glow orb positioned behind artwork
            RadialGradient(
                colors: [
                    self.palette.primary.opacity(0.70),
                    self.palette.primary.opacity(0.20),
                    .clear,
                ],
                center: .init(x: 0.20, y: 0.65),
                startRadius: 20,
                endRadius: 280
            )
            .allowsHitTesting(false)
        }
    }

    private var rightHandDecorativeAura: some View {
        HStack {
            Spacer()

            ZStack {
                // Outer ambient halo
                Circle()
                    .strokeBorder(self.palette.primary.opacity(0.12), lineWidth: 2)
                    .frame(width: 320, height: 320)

                Circle()
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1.5)
                    .frame(width: 240, height: 240)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                self.palette.secondary.opacity(0.30),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)
            }
            .blur(radius: 20)
            .offset(x: 60, y: 20)
            .allowsHitTesting(false)
        }
    }

    private var vignetteLayer: some View {
        ZStack {
            // Bottom-to-top vignette for text legibility
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.30),
                    .black.opacity(0.75),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Leading-to-trailing subtle dark vignette
            LinearGradient(
                colors: [
                    .black.opacity(0.40),
                    .clear,
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .allowsHitTesting(false)
    }

    // MARK: - Artwork View

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
                            .fill(self.palette.primary.opacity(0.35))
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                    }
                } else {
                    Rectangle()
                        .fill(self.palette.primary.opacity(0.35))
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                }
            }
            .frame(width: Self.artworkSize, height: Self.artworkSize)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1.5)
            )
            .shadow(color: self.palette.primary.opacity(0.55), radius: 42, x: 0, y: 14)
            .shadow(color: .black.opacity(0.40), radius: 16, x: 0, y: 8)
            .scaleEffect(self.isHovering ? 1.02 : 1.0)
            .animation(AppAnimation.spring, value: self.isHovering)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Details & Actions

    private var detailsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Badge (if present)
            if let badgeText = self.heroItem.badgeText, !badgeText.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: self.badgeIconName(for: badgeText))
                        .font(.system(size: 10, weight: .bold))
                    Text(badgeText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.6)
                }
                .foregroundStyle(.white.opacity(0.95))
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .compatGlass(interactive: false, in: .capsule)
            }

            // Title
            Button(action: self.onNavigate) {
                Text(self.heroItem.title)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            // Artist Subtitle
            Text(self.heroItem.artistSubtitle)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.90))
                .lineLimit(1)

            // Editorial Description
            if let editorial = self.heroItem.editorialDescription, !editorial.isEmpty {
                Text(editorial)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
                .frame(height: 4)

            // Action Row
            HStack(spacing: 14) {
                // Primary Action Button (Start Listening)
                Button(action: self.onPlay) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Start Listening")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                }
                .compatGlassProminentButton()
                .tint(.white)
                .foregroundStyle(.black)
                .accessibilityLabel(String(localized: "Start listening to \(self.heroItem.title)"))

                // Secondary Action Button (View Details)
                Button(action: self.onNavigate) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("View Details")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .compatGlass(interactive: true, in: .capsule)
            }
        }
    }

    private func badgeIconName(for text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("supermix") {
            return "sparkles"
        }
        if lower.contains("rotation") {
            return "flame.fill"
        }
        if lower.contains("album") {
            return "square.stack.fill"
        }
        return "music.note"
    }
}
