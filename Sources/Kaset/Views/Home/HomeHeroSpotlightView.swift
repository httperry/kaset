//
//  HomeHeroSpotlightView.swift
//  Kaset
//
//  Clean, vibrant Apple-Music style Hero Spotlight Stage.
//

import SwiftUI

// MARK: - HomeHeroSpotlightView

/// Sleek, vibrant 380pt cinematic stage using a foolproof blurred-artwork backdrop.
struct HomeHeroSpotlightView: View {
    let heroItems: [HomeHeroItemPayload]
    let onPlayTarget: (HomePlayTarget) -> Void
    let onNavigateTarget: (HomePlayTarget) -> Void
    let onNavigateArtist: (Artist) -> Void

    @State private var selectedIndex: Int = 0
    @State private var palette: ColorExtractor.ColorPalette = .default
    @State private var isHovering = false

    private static let bannerHeight: CGFloat = 380
    private static let artworkSize: CGFloat = 240

    private var currentItem: HomeHeroItemPayload? {
        guard !self.heroItems.isEmpty else { return nil }
        let index = min(self.selectedIndex, self.heroItems.count - 1)
        return self.heroItems[index]
    }

    var body: some View {
        if let currentItem {
            ZStack(alignment: .bottomLeading) {
                // Layer 1: Base Fallback Color
                Color(nsColor: .windowBackgroundColor)

                // Layer 2: Foolproof Full-Bleed Blurred Artwork Background
                self.vibrantBlurredBackdrop(for: currentItem)

                // Layer 3: Dark Gradient Overlay (For Text Legibility & Depth)
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.1), location: 0.0),
                        .init(color: .black.opacity(0.4), location: 0.5),
                        .init(color: .black.opacity(0.85), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                // Layer 4: Content (Bottom Aligned, Apple-style)
                HStack(alignment: .bottom, spacing: 32) {
                    // Left Artwork Box
                    self.artworkView(for: currentItem)

                    // Right Details
                    self.detailsView(for: currentItem)

                    Spacer(minLength: 0)

                    // Bottom-Right Controls
                    if self.heroItems.count > 1 {
                        self.carouselControls
                            .padding(.bottom, 6)
                    }
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.bannerHeight)
            .clipShape(.rect(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
            .contentShape(.rect(cornerRadius: 24))
            .onHover { hovering in
                withAnimation(AppAnimation.quick) {
                    self.isHovering = hovering
                }
            }
            .task(id: currentItem.id) {
                if let url = currentItem.thumbnailURL {
                    self.palette = await ColorExtractor.cachedPalette(for: url)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(String(localized: "Featured: \(currentItem.title) by \(currentItem.artistSubtitle)"))
        }
    }

    // MARK: - Vibrant Blurred Backdrop

    private func vibrantBlurredBackdrop(for item: HomeHeroItemPayload) -> some View {
        ZStack {
            if let url = item.thumbnailURL?.highQualityThumbnailURL {
                CachedAsyncImage(
                    url: url,
                    targetSize: CGSize(width: 800, height: 800)
                ) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: Self.bannerHeight)
                        .blur(radius: 80, opaque: true)
                        .saturation(1.4)
                } placeholder: {
                    Rectangle().fill(self.palette.primary.opacity(0.3))
                }
            }
            
            // Add a subtle color-mesh glow from the palette on the right side
            HStack {
                Spacer()
                Circle()
                    .fill(self.palette.secondary.opacity(0.4))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .offset(x: 100, y: 0)
            }
        }
        .allowsHitTesting(false)
        .clipped()
    }

    // MARK: - Artwork View (Left Box)

    private func artworkView(for item: HomeHeroItemPayload) -> some View {
        Button {
            self.onPlayTarget(item.playTarget)
        } label: {
            ZStack {
                if let url = item.thumbnailURL?.highQualityThumbnailURL {
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
                                    .font(.system(size: 64))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                    }
                }

                // Hover Play Icon
                Circle()
                    .fill(.black.opacity(self.isHovering ? 0.5 : 0.0))
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: 2)
                            .opacity(self.isHovering ? 1.0 : 0.0)
                    }
                    .animation(AppAnimation.quick, value: self.isHovering)
            }
            .frame(width: Self.artworkSize, height: Self.artworkSize)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 12)
            .scaleEffect(self.isHovering ? 1.02 : 1.0)
            .animation(AppAnimation.spring, value: self.isHovering)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Details & Action Buttons

    private func detailsView(for item: HomeHeroItemPayload) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Badge Pill
            if let badgeText = item.badgeText, !badgeText.isEmpty {
                Text(badgeText.uppercased())
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(.capsule)
                    .padding(.bottom, 2)
            }

            // Big Title
            Button {
                self.onPlayTarget(item.playTarget)
            } label: {
                Text(item.title)
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            // Artist Subtitle
            if let artist = item.playTarget.artist {
                Button {
                    self.onNavigateArtist(artist)
                } label: {
                    Text(item.artistSubtitle)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            } else {
                Text(item.artistSubtitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }

            // Contextual Narrative
            if let editorial = item.editorialDescription, !editorial.isEmpty {
                Text(editorial)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)
                    .padding(.top, 4)
            }

            Spacer()
                .frame(height: 12)

            // Action Row - Solid, high contrast buttons
            HStack(spacing: 12) {
                Button {
                    self.onPlayTarget(item.playTarget)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Play")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(.capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Start listening to \(item.title)"))

                Button {
                    self.onNavigateTarget(item.playTarget)
                } label: {
                    Text("Details")
                        .font(.system(size: 15, weight: .bold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .foregroundStyle(.white)
                        .clipShape(.capsule)
                        .overlay(
                            Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Carousel Controls

    private var carouselControls: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(AppAnimation.smooth) {
                    self.selectedIndex = (self.selectedIndex - 1 + self.heroItems.count) % self.heroItems.count
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial)
                    .clipShape(.circle)
                    .foregroundStyle(.white)
                    .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(AppAnimation.smooth) {
                    self.selectedIndex = (self.selectedIndex + 1) % self.heroItems.count
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial)
                    .clipShape(.circle)
                    .foregroundStyle(.white)
                    .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private func badgeIcon(for text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("supermix") { return "sparkles" }
        if lower.contains("rotation") { return "flame.fill" }
        if lower.contains("album") { return "square.stack.fill" }
        return "music.note"
    }
}
