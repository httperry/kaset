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
}

// MARK: - HomeHeroItemPayload

/// Data payload for the full-width cinematic Hero banner.
struct HomeHeroItemPayload: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let artistSubtitle: String
    let editorialDescription: String?
    let thumbnailURL: URL?
    let badgeText: String?
    let playTarget: HomePlayTarget

    init(
        id: String,
        title: String,
        artistSubtitle: String,
        editorialDescription: String? = nil,
        thumbnailURL: URL? = nil,
        badgeText: String? = nil,
        playTarget: HomePlayTarget
    ) {
        self.id = id
        self.title = title
        self.artistSubtitle = artistSubtitle
        self.editorialDescription = editorialDescription
        self.thumbnailURL = thumbnailURL
        self.badgeText = badgeText
        self.playTarget = playTarget
    }
}

// MARK: - HomeBentoItemPayload

/// Data payload for the 2-row asymmetric "Jump Back In" activity bento.
struct HomeBentoItemPayload: Identifiable, Equatable, Sendable {
    let id: String
    let primaryItem: HomeSectionItem
    let secondaryItems: [HomeSectionItem]

    init(
        id: String = "home-bento-jump-back-in",
        primaryItem: HomeSectionItem,
        secondaryItems: [HomeSectionItem]
    ) {
        self.id = id
        self.primaryItem = primaryItem
        self.secondaryItems = secondaryItems
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
    let heroItem: HomeHeroItemPayload?
    let jumpBackIn: HomeBentoItemPayload?
    let curatedShelves: [HomeCuratedShelfPayload]

    init(
        heroItem: HomeHeroItemPayload? = nil,
        jumpBackIn: HomeBentoItemPayload? = nil,
        curatedShelves: [HomeCuratedShelfPayload] = []
    ) {
        self.heroItem = heroItem
        self.jumpBackIn = jumpBackIn
        self.curatedShelves = curatedShelves
    }

    var isEmpty: Bool {
        self.heroItem == nil && self.jumpBackIn == nil && self.curatedShelves.isEmpty
    }
}
