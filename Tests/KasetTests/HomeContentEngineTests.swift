//
//  HomeContentEngineTests.swift
//  KasetTests
//

import Foundation
import Testing
@testable import Kaset

@Suite("Home Content Engine Tests")
@MainActor
struct HomeContentEngineTests {
    @Test("Selects Supermix as Hero banner when present")
    func selectsSupermixHero() {
        let affinityEngine = UserAffinityEngine(skipPersistence: true)

        let supermixPlaylist = TestFixtures.makePlaylist(id: "RDTMAK5uy", title: "Your Supermix")
        let supermixSection = HomeSection(
            id: "sec-supermix",
            title: "Mixed for you",
            items: [.playlist(supermixPlaylist)]
        )

        let regularSong = TestFixtures.makeSong(id: "s-1", title: "Regular Song")
        let regularSection = HomeSection(id: "sec-quick", title: "Quick picks", items: [.song(regularSong)])

        let provisioned = HomeContentEngine.process(
            rawSections: [supermixSection, regularSection],
            affinityEngine: affinityEngine
        )

        #expect(provisioned.heroItem != nil)
        #expect(provisioned.heroItem?.title == "Your Supermix")
        #expect(provisioned.heroItem?.badgeText == "SUPERMIX")
    }

    @Test("Selects Jump Back In Bento with 1 primary and up to 4 secondary items")
    func selectsJumpBackInBento() {
        let affinityEngine = UserAffinityEngine(skipPersistence: true)

        let album = TestFixtures.makeAlbum(id: "alb-1", title: "After Hours", artistName: "The Weeknd")
        let songs = (1 ... 5).map { idx in
            TestFixtures.makeSong(id: "s-\(idx)", title: "Song \(idx)", artistName: "Artist \(idx)")
        }

        var items: [HomeSectionItem] = [.album(album)]
        items.append(contentsOf: songs.map { .song($0) })

        let listenAgainSection = HomeSection(id: "sec-listen", title: "Listen again", items: items)

        let provisioned = HomeContentEngine.process(
            rawSections: [listenAgainSection],
            affinityEngine: affinityEngine
        )

        #expect(provisioned.jumpBackIn != nil)
        #expect(provisioned.jumpBackIn?.primaryItem.title == "After Hours")
        #expect(provisioned.jumpBackIn?.secondaryItems.count == 4)
    }

    @Test("Classifies raw sections into typed shelf contents")
    func classifiesSections() {
        let songs = (0 ..< 4).map { TestFixtures.makeSong(id: "s-\($0)", title: "Track \($0)") }
        let songSection = HomeSection(id: "sec-1", title: "Quick picks", items: songs.map { .song($0) })

        let albums = (0 ..< 3).map { TestFixtures.makeAlbum(id: "a-\($0)", title: "Album \($0)") }
        let albumSection = HomeSection(id: "sec-2", title: "Albums for you", items: albums.map { .album($0) })

        let artists = (0 ..< 3).map { TestFixtures.makeArtist(id: "art-\($0)", name: "Artist \($0)") }
        let artistSection = HomeSection(id: "sec-3", title: "Your favorite artists", items: artists.map { .artist($0) })

        let provisioned = HomeContentEngine.process(
            rawSections: [songSection, albumSection, artistSection],
            affinityEngine: UserAffinityEngine(skipPersistence: true)
        )

        #expect(provisioned.curatedShelves.count == 3)

        // Shelf 0: Song Tracks
        if case let .songTracks(tracks) = provisioned.curatedShelves[0].content {
            #expect(tracks.count == 4)
        } else {
            Issue.record("Expected songTracks shelf for Quick picks")
        }

        // Shelf 1: Albums and Playlists
        if case let .albumsAndPlaylists(items) = provisioned.curatedShelves[1].content {
            #expect(items.count == 3)
        } else {
            Issue.record("Expected albumsAndPlaylists shelf for Albums for you")
        }

        // Shelf 2: Artist Portraits
        if case let .artistPortraits(arts) = provisioned.curatedShelves[2].content {
            #expect(arts.count == 3)
        } else {
            Issue.record("Expected artistPortraits shelf for Your favorite artists")
        }
    }

    @Test("Filters out zero-affinity promotional shelves")
    func filtersPromotionalShelves() {
        let affinityEngine = UserAffinityEngine(skipPersistence: true)

        let promoSongs = (0 ..< 4).map {
            TestFixtures.makeSong(id: "promo-\($0)", title: "Promo \($0)", artistName: "Sponsored Pop Star")
        }
        let promoSection = HomeSection(id: "sec-promo", title: "Sponsored Pop Star", items: promoSongs.map { .song($0) })

        let regularSongs = (0 ..< 4).map {
            TestFixtures.makeSong(id: "reg-\($0)", title: "Track \($0)")
        }
        let regularSection = HomeSection(id: "sec-reg", title: "Quick picks", items: regularSongs.map { .song($0) })

        let provisioned = HomeContentEngine.process(
            rawSections: [promoSection, regularSection],
            affinityEngine: affinityEngine
        )

        // The promotional section should be filtered out
        #expect(provisioned.curatedShelves.count == 1)
        #expect(provisioned.curatedShelves.first?.title == "Quick picks")
    }

    @Test("Anti-habituation rotates Hero selection when multiple elite candidates exist")
    func antiHabituationHeroRotation() {
        let affinityEngine = UserAffinityEngine(skipPersistence: true)

        let supermix = TestFixtures.makePlaylist(id: "supermix-1", title: "Your Supermix")
        let supermixSection = HomeSection(id: "sec-mix", title: "Mixed for you", items: [.playlist(supermix)])

        let heavySong = TestFixtures.makeSong(id: "heavy-1", title: "90210", artistName: "Travis Scott")
        let heavySection = HomeSection(id: "sec-heavy", title: "Listen again", items: [.song(heavySong)])

        // First selection: picks supermix and marks it shown
        let run1 = HomeContentEngine.process(
            rawSections: [supermixSection, heavySection],
            affinityEngine: affinityEngine
        )
        #expect(run1.heroItem?.id == "playlist-supermix-1")

        // Second selection: supermix was just shown, so anti-habituation rotates to next elite candidate
        let run2 = HomeContentEngine.process(
            rawSections: [supermixSection, heavySection],
            affinityEngine: affinityEngine
        )
        #expect(run2.heroItem?.id == "song-heavy-1")
    }

    @Test("Bento enforces artist diversity across secondary pills")
    func bentoEnforcesArtistDiversity() {
        let affinityEngine = UserAffinityEngine(skipPersistence: true)

        let album = TestFixtures.makeAlbum(id: "alb-main", title: "Main Album", artistName: "Primary Artist")

        // 4 songs by same artist, 2 songs by different artists
        let songsSameArtist = (1 ... 4).map { TestFixtures.makeSong(id: "same-\($0)", title: "Same \($0)", artistName: "Dominant Artist") }
        let songOther1 = TestFixtures.makeSong(id: "other-1", title: "Other 1", artistName: "Different Artist 1")
        let songOther2 = TestFixtures.makeSong(id: "other-2", title: "Other 2", artistName: "Different Artist 2")

        var items: [HomeSectionItem] = [.album(album)]
        items.append(contentsOf: songsSameArtist.map { .song($0) })
        items.append(.song(songOther1))
        items.append(.song(songOther2))

        let section = HomeSection(id: "sec-div", title: "Listen again", items: items)
        let provisioned = HomeContentEngine.process(rawSections: [section], affinityEngine: affinityEngine)

        guard let bento = provisioned.jumpBackIn else {
            Issue.record("Expected bento")
            return
        }

        let dominantCount = bento.secondaryItems.filter { $0.subtitle?.contains("Dominant Artist") == true }.count
        #expect(dominantCount <= 2) // Max 2 per artist
        #expect(bento.secondaryItems.count == 4)
    }
}
