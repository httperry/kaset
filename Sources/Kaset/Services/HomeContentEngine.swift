//
//  HomeContentEngine.swift
//  Kaset
//
//  Main algorithmic engine for curating and provisioning the Home screen.
//

import Foundation
import os

// MARK: - HomeContentEngine

/// Algorithmic engine that transforms raw YouTube Music sections and user affinity signals
/// into a structured, curated Home feed with Hero, Activity Bento, and classified shelves.
@MainActor
enum HomeContentEngine {
    private static let logger = DiagnosticsLogger.api

    /// Curates and provisions the complete Home screen data payload.
    static func process(
        rawSections: [HomeSection],
        affinityEngine: UserAffinityEngine = .shared
    ) -> HomeProvisionedContent {
        guard !rawSections.isEmpty else {
            return HomeProvisionedContent()
        }

        // 1. Select Hero Candidate
        let heroItem = Self.selectHeroItem(from: rawSections, affinityEngine: affinityEngine)

        // 2. Select Activity Bento ("Jump Back In")
        let jumpBackIn = Self.selectJumpBackIn(from: rawSections, affinityEngine: affinityEngine)

        // 3. Process & Classify Downstream Shelves
        var curatedShelves: [HomeCuratedShelfPayload] = []

        for section in rawSections {
            // Apply Promotional Filter
            if affinityEngine.isPromotionalShelf(title: section.title, items: section.items) {
                Self.logger.info("HomeContentEngine dropped promotional section: \(section.title)")
                continue
            }

            guard let shelf = Self.classifySection(section) else { continue }
            curatedShelves.append(shelf)
        }

        return HomeProvisionedContent(
            heroItem: heroItem,
            jumpBackIn: jumpBackIn,
            curatedShelves: curatedShelves
        )
    }

    // MARK: - Hero Selection

    /// Selects or synthesizes the top featured Hero banner item.
    static func selectHeroItem(
        from sections: [HomeSection],
        affinityEngine _: UserAffinityEngine
    ) -> HomeHeroItemPayload? {
        // Priority 1: Check for "Your Supermix" or "My Mix" in raw sections
        for section in sections {
            for item in section.items {
                let lowerTitle = item.title.lowercased()
                if lowerTitle.contains("supermix") || lowerTitle.contains("my mix") {
                    let artists = Self.extractTopArtistsSummary(from: section.items)
                    return HomeHeroItemPayload(
                        id: item.id,
                        title: item.title,
                        artistSubtitle: artists.isEmpty ? (item.subtitle ?? "Personalized Mix") : artists,
                        editorialDescription: "An endless personalized mix combining your favorite daily tracks with fresh new discoveries.",
                        thumbnailURL: item.thumbnailURL,
                        badgeText: "SUPERMIX",
                        playTarget: Self.makePlayTarget(from: item)
                    )
                }
            }
        }

        // Priority 2: Top item from "Listen again" or "Quick picks"
        if let firstSection = sections.first(where: {
            let lower = $0.title.lowercased()
            return lower.contains("listen again") || lower.contains("quick picks") || lower.contains("favourites")
        }), let firstItem = firstSection.items.first {
            return HomeHeroItemPayload(
                id: firstItem.id,
                title: firstItem.title,
                artistSubtitle: firstItem.subtitle ?? "Featured",
                editorialDescription: "Jump back into your recent rotation with curated recommendations.",
                thumbnailURL: firstItem.thumbnailURL,
                badgeText: "HEAVY ROTATION",
                playTarget: self.makePlayTarget(from: firstItem)
            )
        }

        // Priority 3: First available item
        if let firstItem = sections.first?.items.first {
            return HomeHeroItemPayload(
                id: firstItem.id,
                title: firstItem.title,
                artistSubtitle: firstItem.subtitle ?? "Featured",
                editorialDescription: "Discover music tailored for you today.",
                thumbnailURL: firstItem.thumbnailURL,
                badgeText: nil,
                playTarget: Self.makePlayTarget(from: firstItem)
            )
        }

        return nil
    }

    // MARK: - Jump Back In Selection

    /// Selects the 1 primary feature item and 4 secondary pill items for the Activity Bento.
    static func selectJumpBackIn(
        from sections: [HomeSection],
        affinityEngine _: UserAffinityEngine
    ) -> HomeBentoItemPayload? {
        // Collect candidate items from "Listen again", "Quick picks", "From your Library"
        var candidateItems: [HomeSectionItem] = []

        for section in sections {
            let lower = section.title.lowercased()
            if lower.contains("listen again") || lower.contains("jump back in") || lower.contains("library") || lower.contains("quick picks") {
                candidateItems.append(contentsOf: section.items)
            }
        }

        // Fallback to all items if specific shelves aren't present
        if candidateItems.isEmpty {
            candidateItems = sections.flatMap(\.items)
        }

        // Deduplicate candidates by ID
        var seenIDs = Set<String>()
        let uniqueCandidates = candidateItems.filter { seenIDs.insert($0.id).inserted }

        guard !uniqueCandidates.isEmpty else { return nil }

        // Find best primary candidate (prefer an album or playlist over an isolated song)
        let primaryItem = uniqueCandidates.first { item in
            if case .album = item {
                return true
            }
            if case .playlist = item {
                return true
            }
            return false
        } ?? uniqueCandidates[0]

        // Secondary items: next 4 distinct items excluding the primary
        let secondaryItems = uniqueCandidates
            .filter { $0.id != primaryItem.id }
            .prefix(4)

        return HomeBentoItemPayload(
            primaryItem: primaryItem,
            secondaryItems: Array(secondaryItems)
        )
    }

    // MARK: - Section Classification

    /// Classifies a raw `HomeSection` into its optimal typed presentation shelf.
    static func classifySection(_ section: HomeSection) -> HomeCuratedShelfPayload? {
        guard !section.items.isEmpty else { return nil }

        let lowerTitle = section.title.lowercased()

        // 1. Artist Avatars Shelf
        let isAllArtists = section.items.allSatisfy {
            if case .artist = $0 {
                true
            } else {
                false
            }
        }
        if isAllArtists {
            let artists = section.items.compactMap {
                if case let .artist(a) = $0 {
                    a
                } else {
                    nil
                }
            }
            return HomeCuratedShelfPayload(
                id: section.id,
                title: section.title,
                content: .artistPortraits(artists)
            )
        }

        // 2. Video Performances Shelf (16:9)
        let isVideoShelf = lowerTitle.contains("video") || lowerTitle.contains("performance") || lowerTitle.contains("live")
        if isVideoShelf {
            let songs = section.items.compactMap { item -> Song? in
                if case let .song(s) = item {
                    return s
                }
                return nil
            }
            if !songs.isEmpty {
                return HomeCuratedShelfPayload(
                    id: section.id,
                    title: section.title,
                    content: .videoPerformances(songs)
                )
            }
        }

        // 3. Audio Songs Shelf (3-Row Track Stacks)
        let isAllSongs = section.items.allSatisfy {
            if case .song = $0 {
                true
            } else {
                false
            }
        }
        let isSongShelf = lowerTitle.contains("quick picks") || lowerTitle.contains("songs") || lowerTitle.contains("remixes")
        if isAllSongs || isSongShelf {
            let songs = section.items.compactMap { item -> Song? in
                if case let .song(s) = item {
                    return s
                }
                return nil
            }
            if !songs.isEmpty {
                return HomeCuratedShelfPayload(
                    id: section.id,
                    title: section.title,
                    content: .songTracks(songs)
                )
            }
        }

        // 4. Default: Medium Album / Playlist Cards
        return HomeCuratedShelfPayload(
            id: section.id,
            title: section.title,
            content: .albumsAndPlaylists(section.items)
        )
    }

    // MARK: - Helper Methods

    private static func makePlayTarget(from item: HomeSectionItem) -> HomePlayTarget {
        switch item {
        case let .song(song):
            .song(song)
        case let .album(album):
            .album(album)
        case let .playlist(playlist):
            .playlist(playlist)
        case let .artist(artist):
            .artist(artist)
        }
    }

    private static func extractTopArtistsSummary(from items: [HomeSectionItem]) -> String {
        var artistSet: [String] = []
        for item in items {
            if let artist = item.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines), !artist.isEmpty {
                if !artistSet.contains(artist) {
                    artistSet.append(artist)
                }
            }
        }
        guard !artistSet.isEmpty else { return "" }
        if artistSet.count <= 3 {
            return artistSet.joined(separator: ", ")
        }
        return "\(artistSet.prefix(3).joined(separator: ", ")) & more"
    }
}
