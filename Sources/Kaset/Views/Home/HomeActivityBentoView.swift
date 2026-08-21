//
//  HomeActivityBentoView.swift
//  Kaset
//
//  2-Row Asymmetric Bento Grid for "Jump Back In" (1 feature card + 4 horizontal pills).
//

import SwiftUI

// MARK: - HomeActivityBentoView

/// 2-Row Asymmetric Bento Grid displaying recent activity and top rotation ("Jump Back In").
struct HomeActivityBentoView: View {
    let bentoPayload: HomeBentoItemPayload
    let onPlayItem: (HomeSectionItem) -> Void
    let onNavigateItem: (HomeSectionItem) -> Void
    var onViewMore: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section Header
            HStack(spacing: 8) {
                // Leading Icon
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.tint)

                Text("Jump Back In")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                // Trailing "See All" Button
                if let onViewMore {
                    Button(action: onViewMore) {
                        HStack(spacing: 4) {
                            Text("See All")
                                .font(.system(size: 13, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Asymmetric Bento Layout
            HStack(alignment: .top, spacing: 14) {
                // Left 2-Row Primary Feature Card
                self.primaryFeatureCard(self.bentoPayload.primaryItem)

                // Right 4 Pill Cards (2x2 Grid)
                if !self.bentoPayload.secondaryItems.isEmpty {
                    self.secondaryPillsGrid(self.bentoPayload.secondaryItems)
                }
            }
        }
    }

    // MARK: - Primary Feature Card (Spans 2 Rows)

    private func primaryFeatureCard(_ item: HomeSectionItem) -> some View {
        Button {
            self.onNavigateItem(item)
        } label: {
            HStack(spacing: 16) {
                // Artwork Box
                ZStack {
                    if let url = item.thumbnailURL {
                        CachedAsyncImage(
                            url: url,
                            targetSize: CGSize(width: 136, height: 136)
                        ) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .overlay {
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.secondary)
                                }
                        }
                    } else {
                        Rectangle()
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay {
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: 136, height: 136)
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)

                // Text Details
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let subtitle = item.homeCardSubtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    // Quick Play Button
                    Button {
                        self.onPlayItem(item)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Play")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                    }
                    .compatGlassProminentButton()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(width: 350, height: 164)
            .compatGlass(interactive: true, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Featured in Jump Back In: \(item.title)"))
    }

    // MARK: - Secondary Pills (2x2 Grid)

    private func secondaryPillsGrid(_ items: [HomeSectionItem]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(items.prefix(4)) { item in
                self.pillCard(item)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func pillCard(_ item: HomeSectionItem) -> some View {
        Button {
            self.onNavigateItem(item)
        } label: {
            HStack(spacing: 12) {
                // Artwork
                ZStack {
                    if let url = item.thumbnailURL {
                        CachedAsyncImage(
                            url: url,
                            targetSize: CGSize(width: 54, height: 54)
                        ) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .overlay {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.secondary)
                                }
                        }
                    } else {
                        Rectangle()
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(width: 54, height: 54)
                .clipShape(.rect(cornerRadius: 8))

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let subtitle = item.homeCardSubtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                // Quick Play Circle
                Button {
                    self.onPlayItem(item)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 28, height: 28)
                        .compatGlass(interactive: true, in: .circle)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .compatGlass(interactive: true, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
