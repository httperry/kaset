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

        // 1. Select Multi-Item Hero Spotlights
        let heroItems = Self.selectHeroItems(from: rawSections, affinityEngine: affinityEngine)

        // 2. Select Jump Back In Recent Items (Consolidating Jump Back In, Listen Again, and Recent Rotation)
        let jumpBackIn = Self.selectJumpBackIn(from: rawSections, affinityEngine: affinityEngine)

        // 3. Process & Classify Downstream Shelves
        var curatedShelves: [HomeCuratedShelfPayload] = []

        for section in rawSections {
            let lower = section.title.lowercased()
            // Consolidate: Skip "Listen again" and "Jump back in" from downstream shelves
            if lower.contains("listen again") || lower.contains("jump back in") {
                Self.logger.info("HomeContentEngine consolidated section into top Jump Back In: \(section.title)")
                continue
            }

            // Apply Promotional Filter
            if affinityEngine.isPromotionalShelf(title: section.title, items: section.items) {
                Self.logger.info("HomeContentEngine dropped promotional section: \(section.title)")
                continue
            }

            guard let shelf = Self.classifySection(section) else { continue }
            curatedShelves.append(shelf)
        }

        return HomeProvisionedContent(
            heroItems: heroItems,
            jumpBackIn: jumpBackIn,
            curatedShelves: curatedShelves
        )
    }

    // MARK: - Hero Selection

    private struct ScoredHeroCandidate {
        let item: HomeSectionItem
        let score: Double
        let badgeText: String?
        let isSupermix: Bool
    }

    /// Selects the top 3 to 5 featured Hero banner items for the Grand Cinematic Stage.
    static func selectHeroItems(
        from sections: [HomeSection],
        affinityEngine: UserAffinityEngine
    ) -> [HomeHeroItemPayload] {
        let candidates = Self.scoreHeroCandidates(from: sections, affinityEngine: affinityEngine)
        guard !candidates.isEmpty else { return [] }

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

        if let firstCandidate = elitePool.first {
            affinityEngine.recordHeroShown(itemId: firstCandidate.item.id)
        }

        return elitePool.map { candidate in
            let item = candidate.item
            let artistInfo = Self.findFeaturedArtistInfo(for: item, in: sections)

            let editorialDesc: String? = if candidate.isSupermix {
                "Continuous personalized mix based on your listening habits."
            } else if let album = item.album, let year = album.year {
                "Album • Released in \(year)"
            } else {
                nil
            }

            return HomeHeroItemPayload(
                id: item.id,
                title: item.title,
                artistSubtitle: item.subtitle ?? "Personalized Selection",
                editorialDescription: editorialDesc,
                thumbnailURL: item.thumbnailURL,
                artistCoverURL: artistInfo.coverURL,
                featuredArtistId: artistInfo.artistId,
                badgeText: candidate.badgeText,
                playTarget: Self.makePlayTarget(from: item)
            )
        }
    }

    /// Convenience single-item hero selector.
    static func selectHeroItem(
        from sections: [HomeSection],
        affinityEngine: UserAffinityEngine
    ) -> HomeHeroItemPayload? {
        self.selectHeroItems(from: sections, affinityEngine: affinityEngine).first
    }

    private static func scoreHeroCandidates(
        from sections: [HomeSection],
        affinityEngine: UserAffinityEngine
    ) -> [ScoredHeroCandidate] {
        var candidates: [ScoredHeroCandidate] = []

        // 1. Check for personalized Supermix / My Mix
        for section in sections {
            for item in section.items {
                let lowerTitle = item.title.lowercased()
                if lowerTitle.contains("supermix") || lowerTitle.contains("my mix") {
                    let score = affinityEngine.computeAffinityScore(
                        videoId: item.videoId,
                        artist: item.subtitle,
                        albumId: item.album?.id
                    )
                    guard score >= 0 else { continue }
                    candidates.append(ScoredHeroCandidate(
                        item: item,
                        score: score,
                        badgeText: "SUPERMIX",
                        isSupermix: true
                    ))
                }
            }
        }

        // 2. Score items across all sections strictly using the psychological composite formula
        for section in sections {
            if affinityEngine.isPromotionalShelf(title: section.title, items: section.items) {
                continue
            }

            for item in section.items {
                let score = affinityEngine.computeAffinityScore(
                    videoId: item.videoId,
                    artist: item.subtitle,
                    albumId: item.album?.id
                )
                guard score >= 0 else { continue }

                let badge: String? = if score >= 60.0 {
                    "HEAVY ROTATION"
                } else if item.album != nil {
                    "ALBUM"
                } else {
                    nil
                }

                candidates.append(ScoredHeroCandidate(
                    item: item,
                    score: score,
                    badgeText: badge,
                    isSupermix: false
                ))
            }
        }

        return candidates
    }

    // MARK: - Jump Back In Selection

    /// Selects the 1 primary feature item and 4 secondary pill items for the Jump Back In shelf.
    static func selectJumpBackIn(
        from sections: [HomeSection],
        affinityEngine: UserAffinityEngine
    ) -> HomeBentoItemPayload? {
        // Collect candidate items from "Listen again", "Jump back in", "Forgotten favorites", "Mixed for you", "Quick picks", "Recent"
        var candidateItems: [HomeSectionItem] = []

        for section in sections {
            let lower = section.title.lowercased()
            if lower.contains("listen again") || lower.contains("jump back in") || lower.contains("forgotten favorites") || lower.contains("quick picks") || lower.contains("mixed for you") || lower.contains("recent") || lower.contains("library") {
                candidateItems.append(contentsOf: section.items)
            }
        }

        if candidateItems.isEmpty {
            candidateItems = sections.flatMap(\.items)
        }

        // Filter out disliked items, video view items, and deduplicate
        var seenIDs = Set<String>()
        var uniqueCandidates = candidateItems.filter { item in
            if let subtitle = item.subtitle?.lowercased(), subtitle.contains("views") {
                return false
            }
            let score = affinityEngine.computeAffinityScore(videoId: item.videoId, artist: item.subtitle, albumId: item.album?.id)
            guard score >= 0 else { return false }
            return seenIDs.insert(item.id).inserted
        }

        guard !uniqueCandidates.isEmpty else { return nil }

        // Sort candidates by composite affinity score and recency
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

        // Anti-habituation for primary item
        if let lastPrimaryID = affinityEngine.profile.lastBentoPrimaryID,
           albumPlaylistCandidates.count > 1,
           albumPlaylistCandidates.first?.id == lastPrimaryID
        {
            let previous = albumPlaylistCandidates.removeFirst()
            albumPlaylistCandidates.append(previous)
        }

        let primaryItem = albumPlaylistCandidates.first ?? uniqueCandidates[0]
        affinityEngine.recordBentoPrimaryShown(itemId: primaryItem.id)

        // Secondary items: collect diverse items with diversity constraint (no more than 2-3 from same artist)
        var secondaryItems: [HomeSectionItem] = []
        var artistCounts: [String: Int] = [:]

        // Seed artist count from primary item
        let primaryArtistKey = primaryItem.subtitle?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !primaryArtistKey.isEmpty {
            artistCounts[primaryArtistKey] = 1
        }

        for item in uniqueCandidates where item.id != primaryItem.id {
            let artistKey = item.subtitle?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let currentCount = artistCounts[artistKey, default: 0]
            if currentCount < 2 || artistKey.isEmpty {
                secondaryItems.append(item)
                if !artistKey.isEmpty {
                    artistCounts[artistKey] = currentCount + 1
                }
            }
            if secondaryItems.count >= 19 {
                break
            }
        }

        return HomeBentoItemPayload(
            id: "home-jump-back-in",
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

    private static func findFeaturedArtistInfo(
        for item: HomeSectionItem,
        in sections: [HomeSection]
    ) -> (artistId: String?, coverURL: URL?) {
        // 1. Direct artist item
        if case let .artist(artist) = item {
            return (artist.id, artist.thumbnailURL?.ultraHighQualityThumbnailURL ?? artist.thumbnailURL)
        }

        // 2. Song with navigable artist
        if case let .song(song) = item, let artist = song.artists.first(where: { $0.hasNavigableId }) {
            return (artist.id, artist.thumbnailURL?.ultraHighQualityThumbnailURL ?? artist.thumbnailURL)
        }

        // 3. Album with navigable artist
        if case let .album(album) = item, let artist = album.artists?.first(where: { $0.hasNavigableId }) {
            return (artist.id, artist.thumbnailURL?.ultraHighQualityThumbnailURL ?? artist.thumbnailURL)
        }

        // 4. Playlist or general item: match artist from subtitle in home sections
        let targetArtistName = item.subtitle?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for section in sections {
            for sectionItem in section.items {
                if case let .artist(artist) = sectionItem {
                    if let name = targetArtistName, !name.isEmpty,
                       artist.name.lowercased() == name || name.contains(artist.name.lowercased())
                    {
                        return (artist.id, artist.thumbnailURL?.ultraHighQualityThumbnailURL ?? artist.thumbnailURL)
                    }
                }
            }
        }

        // 5. Fallback: Find the first prominent artist in the home feed sections
        for section in sections {
            for sectionItem in section.items {
                if case let .artist(artist) = sectionItem, artist.hasNavigableId {
                    return (artist.id, artist.thumbnailURL?.ultraHighQualityThumbnailURL ?? artist.thumbnailURL)
                }
            }
        }

        return (nil, nil)
    }

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
