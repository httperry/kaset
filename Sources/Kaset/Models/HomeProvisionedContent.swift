//
//  HomeProvisionedContent.swift
//  Kaset
//
//  Data contracts for the Home Screen Redesign & Curation Engine.
//

import Foundation

// MARK: - HomePlayTarget

/// Represents the executable play target for a curated Home item.
enum HomePlayTarget: Equatable, Sendable {
    case song(Song)
    case album(Album)
    case playlist(Playlist)
    case artist(Artist)

    var id: String {
        switch self {
        case let .song(song):
            song.id
        case let .album(album):
            album.id
        case let .playlist(playlist):
            playlist.id
        case let .artist(artist):
            artist.id
        }
    }

    var title: String {
        switch self {
        case let .song(song):
            song.title
        case let .album(album):
            album.title
        case let .playlist(playlist):
            playlist.title
        case let .artist(artist):
            artist.name
        }
    }

    var artist: Artist? {
        switch self {
        case let .song(song):
            song.artists.first(where: { $0.hasNavigableId })
        case let .album(album):
            album.artists?.first(where: { $0.hasNavigableId })
        case let .playlist(playlist):
            playlist.author
        case let .artist(artist):
            artist
        }
    }
}

// MARK: - HomeHeroItemPayload

/// Data payload for the full-width cinematic Hero banner.
struct HomeHeroItemPayload: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let artistSubtitle: String
    let editorialDescription: String?
    let thumbnailURL: URL?
    let artistCoverURL: URL?
    let badgeText: String?
    let playTarget: HomePlayTarget

    init(
        id: String,
        title: String,
        artistSubtitle: String,
        editorialDescription: String? = nil,
        thumbnailURL: URL? = nil,
        artistCoverURL: URL? = nil,
        badgeText: String? = nil,
        playTarget: HomePlayTarget
    ) {
        self.id = id
        self.title = title
        self.artistSubtitle = artistSubtitle
        self.editorialDescription = editorialDescription
        self.thumbnailURL = thumbnailURL
        self.artistCoverURL = artistCoverURL
        self.badgeText = badgeText
        self.playTarget = playTarget
    }
}

// MARK: - HomeBentoItemPayload

/// Data payload for the "Jump Back In" recent rotation shelf.
struct HomeBentoItemPayload: Identifiable, Equatable, Sendable {
    let id: String
    let items: [HomeSectionItem]

    var primaryItem: HomeSectionItem {
        self.items.first ?? HomeSectionItem.song(Song(id: "", title: "", artists: [], videoId: ""))
    }

    var secondaryItems: [HomeSectionItem] {
        Array(self.items.dropFirst())
    }

    init(
        id: String = "home-jump-back-in",
        items: [HomeSectionItem]
    ) {
        self.id = id
        self.items = items
    }

    init(
        id: String = "home-jump-back-in",
        primaryItem: HomeSectionItem,
        secondaryItems: [HomeSectionItem]
    ) {
        self.id = id
        self.items = [primaryItem] + secondaryItems
    }
}

// MARK: - HomeShelfContent

/// Typed content payload for a curated downstream shelf.
enum HomeShelfContent: Equatable, Sendable {
    /// 3-row compact track stacks for audio songs.
    case songTracks([Song])
    /// 175pt glowing medium cards for albums, playlists, and mixes.
    case albumsAndPlaylists([HomeSectionItem])
    /// 16:9 landscape cards with duration for videos and live performances.
    case videoPerformances([Song])
    /// 110pt circular artist portraits.
    case artistPortraits([Artist])

    var itemCount: Int {
        switch self {
        case let .songTracks(songs):
            songs.count
        case let .albumsAndPlaylists(items):
            items.count
        case let .videoPerformances(videos):
            videos.count
        case let .artistPortraits(artists):
            artists.count
        }
    }

    var isEmpty: Bool {
        self.itemCount == 0
    }
}

// MARK: - HomeCuratedShelfPayload

/// A classified and curated shelf ready for presentation.
struct HomeCuratedShelfPayload: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let content: HomeShelfContent
}

// MARK: - HomeProvisionedContent

/// Complete provisioned data payload for the Home screen.
struct HomeProvisionedContent: Equatable, Sendable {
    let heroItems: [HomeHeroItemPayload]
    let jumpBackIn: HomeBentoItemPayload?
    let curatedShelves: [HomeCuratedShelfPayload]

    var heroItem: HomeHeroItemPayload? {
        self.heroItems.first
    }

    init(
        heroItems: [HomeHeroItemPayload] = [],
        heroItem: HomeHeroItemPayload? = nil,
        jumpBackIn: HomeBentoItemPayload? = nil,
        curatedShelves: [HomeCuratedShelfPayload] = []
    ) {
        if !heroItems.isEmpty {
            self.heroItems = heroItems
        } else if let heroItem {
            self.heroItems = [heroItem]
        } else {
            self.heroItems = []
        }
        self.jumpBackIn = jumpBackIn
        self.curatedShelves = curatedShelves
    }

    var isEmpty: Bool {
        self.heroItems.isEmpty && self.jumpBackIn == nil && self.curatedShelves.isEmpty
    }
}
