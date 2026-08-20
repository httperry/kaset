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

    /// Selects or synthesizes the top featured Hero banner item using behavioral affinity, time-of-day context, and anti-habituation.
    static func selectHeroItem(
        from sections: [HomeSection],
        affinityEngine: UserAffinityEngine
    ) -> HomeHeroItemPayload? {
        struct ScoredHeroCandidate {
            let item: HomeSectionItem
            let score: Double
            let badgeText: String
            let isSupermix: Bool
        }

        var candidates: [ScoredHeroCandidate] = []

        // 1. Check for "Your Supermix" or "My Mix" in raw sections
        for section in sections {
            for item in section.items {
                let lowerTitle = item.title.lowercased()
                if lowerTitle.contains("supermix") || lowerTitle.contains("my mix") {
                    candidates.append(ScoredHeroCandidate(
                        item: item,
                        score: 180.0,
                        badgeText: "SUPERMIX",
                        isSupermix: true
                    ))
                }
            }
        }

        // 2. Score all valid items across sections
        let allItems = sections.flatMap(\.items)
        for item in allItems {
            let score = affinityEngine.computeAffinityScore(
                videoId: item.videoId,
                artist: item.subtitle,
                albumId: item.album?.id
            )
            // Negative score means disliked/suppressed
            guard score >= 0 else { continue }

            let badge = if score >= 40.0 {
                "HEAVY ROTATION"
            } else if item.album != nil {
                "FEATURED ALBUM"
            } else {
                "FOR YOU"
            }

            candidates.append(ScoredHeroCandidate(
                item: item,
                score: score,
                badgeText: badge,
                isSupermix: false
            ))
        }

        guard !candidates.isEmpty else { return nil }

        // Deduplicate candidates by item ID
        var seenIDs = Set<String>()
        var uniqueCandidates = candidates.filter { seenIDs.insert($0.item.id).inserted }

        // Sort descending by score
        uniqueCandidates.sort { $0.score > $1.score }

        // Take top 5 elite pool
        var elitePool = Array(uniqueCandidates.prefix(5))

        // Anti-Habituation: If top candidate was shown on the previous refresh and alternatives exist, rotate
        if let lastHeroID = affinityEngine.profile.lastHeroItemID,
           elitePool.count > 1,
           elitePool.first?.item.id == lastHeroID
        {
            let previous = elitePool.removeFirst()
            elitePool.append(previous) // Move to back of elite pool
        }

        let selectedCandidate = elitePool.first ?? uniqueCandidates[0]
        let selectedItem = selectedCandidate.item

        // Record chosen hero for anti-habituation on next refresh
        affinityEngine.recordHeroShown(itemId: selectedItem.id)

        let artistSummary = Self.extractTopArtistsSummary(from: [selectedItem])
        let editorialDesc = affinityEngine.generateHeroEditorialDescription(
            title: selectedItem.title,
            artistSummary: artistSummary.isEmpty ? (selectedItem.subtitle ?? "") : artistSummary
        )

        return HomeHeroItemPayload(
            id: selectedItem.id,
            title: selectedItem.title,
            artistSubtitle: selectedItem.subtitle ?? "Personalized Selection",
            editorialDescription: editorialDesc,
            thumbnailURL: selectedItem.thumbnailURL,
            badgeText: selectedCandidate.badgeText,
            playTarget: Self.makePlayTarget(from: selectedItem)
        )
    }

    // MARK: - Jump Back In Selection

    /// Selects the 1 primary feature item and 4 secondary pill items for the Activity Bento.
    static func selectJumpBackIn(
        from sections: [HomeSection],
        affinityEngine: UserAffinityEngine
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

        // Filter out disliked items and deduplicate candidates by ID
        var seenIDs = Set<String>()
        var uniqueCandidates = candidateItems.filter { item in
            let score = affinityEngine.computeAffinityScore(videoId: item.videoId, artist: item.subtitle, albumId: item.album?.id)
            guard score >= 0 else { return false } // Dislike suppression
            return seenIDs.insert(item.id).inserted
        }

        guard !uniqueCandidates.isEmpty else { return nil }

        // Sort candidates by composite affinity & frequency score
        uniqueCandidates.sort { lhs, rhs in
            let lhsScore = affinityEngine.computeAffinityScore(videoId: lhs.videoId, artist: lhs.subtitle, albumId: lhs.album?.id)
            let rhsScore = affinityEngine.computeAffinityScore(videoId: rhs.videoId, artist: rhs.subtitle, albumId: rhs.album?.id)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }

            let lhsRecentIndex = lhs.videoId.flatMap { affinityEngine.profile.recentVideoIDs.firstIndex(of: $0) } ?? Int.max
            let rhsRecentIndex = rhs.videoId.flatMap { affinityEngine.profile.recentVideoIDs.firstIndex(of: $0) } ?? Int.max
            return lhsRecentIndex < rhsRecentIndex
        }

        // Find primary candidate (prefer an album or playlist over an isolated song)
        var albumPlaylistCandidates = uniqueCandidates.filter { item in
            if case .album = item {
                return true
            }
            if case .playlist = item {
                return true
            }
            return false
        }

        // Anti-habituation for Bento primary item
        if let lastPrimaryID = affinityEngine.profile.lastBentoPrimaryID,
           albumPlaylistCandidates.count > 1,
           albumPlaylistCandidates.first?.id == lastPrimaryID
        {
            let previous = albumPlaylistCandidates.removeFirst()
            albumPlaylistCandidates.append(previous)
        }

        let primaryItem = albumPlaylistCandidates.first ?? uniqueCandidates[0]
        affinityEngine.recordBentoPrimaryShown(itemId: primaryItem.id)

        // Secondary items: next 4 distinct items with diversity constraint (no more than 2 from same artist)
        var secondaryItems: [HomeSectionItem] = []
        var artistCountInPills: [String: Int] = [:]

        for item in uniqueCandidates where item.id != primaryItem.id {
            let artistKey = item.subtitle?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let currentCount = artistCountInPills[artistKey, default: 0]
            if currentCount < 2 || artistKey.isEmpty {
                secondaryItems.append(item)
                if !artistKey.isEmpty {
                    artistCountInPills[artistKey] = currentCount + 1
                }
            }
            if secondaryItems.count == 4 {
                break
            }
        }

        return HomeBentoItemPayload(
            primaryItem: primaryItem,
            secondaryItems: secondaryItems
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
