//
//  UserAffinityEngineTests.swift
//  KasetTests
//

import Foundation
import Testing
@testable import Kaset

@Suite("User Affinity Engine Tests")
@MainActor
struct UserAffinityEngineTests {
    @Test("Recording play updates play count, artist score, and recents")
    func recordPlayUpdatesAffinity() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let engine = UserAffinityEngine(storageDirectory: tempDir, skipPersistence: true)

        engine.recordPlay(
            videoId: "vid-123",
            artist: "The Weeknd",
            albumId: "album-456",
            genre: "R&B",
            completed: true
        )

        #expect(engine.profile.trackPlayCounts["vid-123"] == 1)
        #expect(engine.affinityScore(forArtist: "The Weeknd") == 20)
        #expect(engine.profile.genreScores["R&B"] == 5)
        #expect(engine.profile.recentVideoIDs.first == "vid-123")
        #expect(engine.profile.recentAlbumIDs.first == "album-456")
    }

    @Test("Recording likes boosts artist affinity significantly")
    func recordLikeBoostsScore() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let engine = UserAffinityEngine(storageDirectory: tempDir, skipPersistence: true)

        engine.recordLike(videoId: "vid-789", artist: "Travis Scott")

        #expect(engine.profile.likedVideoIDs.contains("vid-789"))
        #expect(engine.affinityScore(forArtist: "Travis Scott") == 50)
    }

    @Test("Promotional filter detects and flags zero-affinity single-artist shelves")
    func promotionalFilterDetection() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let engine = UserAffinityEngine(storageDirectory: tempDir, skipPersistence: true)

        // Give user high affinity for The Weeknd
        engine.recordPlay(videoId: "vid-1", artist: "The Weeknd", completed: true)

        // Create a shelf for Camila Cabello (0 affinity)
        let camilaItems: [HomeSectionItem] = (0 ..< 4).map { idx in
            .song(TestFixtures.makeSong(
                id: "camila-\(idx)",
                title: "Havana \(idx)",
                artistName: "Camila Cabello"
            ))
        }

        let isCamilaPromo = engine.isPromotionalShelf(title: "Camila Cabello", items: camilaItems)
        #expect(isCamilaPromo == true)

        // Create a shelf for The Weeknd (positive affinity)
        let weekndItems: [HomeSectionItem] = (0 ..< 4).map { idx in
            .song(TestFixtures.makeSong(
                id: "weeknd-\(idx)",
                title: "Blinding Lights \(idx)",
                artistName: "The Weeknd"
            ))
        }

        let isWeekndPromo = engine.isPromotionalShelf(title: "The Weeknd", items: weekndItems)
        #expect(isWeekndPromo == false)

        // Generic shelves like "Quick picks" should never be flagged as promotional
        let quickPicks = engine.isPromotionalShelf(title: "Quick picks", items: camilaItems)
        #expect(quickPicks == false)
    }

    @Test("Cloud delta reconciliation updates history and likes")
    func cloudReconciliation() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let engine = UserAffinityEngine(storageDirectory: tempDir, skipPersistence: true)

        let historySong = TestFixtures.makeSong(id: "hist-1", title: "Starboy", artistName: "The Weeknd")
        let historySection = HomeSection(id: "sec-hist", title: "History", items: [.song(historySong)])

        engine.reconcileWithCloudHistory(historySections: [historySection])

        #expect(engine.profile.trackPlayCounts["hist-1"] == 1)
        #expect(engine.affinityScore(forArtist: "The Weeknd") == 20)

        let likedSong = TestFixtures.makeSong(id: "like-1", title: "Espresso", artistName: "Sabrina Carpenter")
        engine.reconcileWithCloudLikes(likedSongs: [likedSong])

        #expect(engine.profile.likedVideoIDs.contains("like-1"))
        #expect(engine.affinityScore(forArtist: "Sabrina Carpenter") == 20)
        #expect(engine.profile.lastSyncedAt != nil)
    }

    @Test("Ebbinghaus temporal decay exponentially reduces older plays")
    func temporalDecayExponential() {
        let weight1h = UserAffinityEngine.temporalDecayWeight(elapsedHours: 1.0)
        let weight24h = UserAffinityEngine.temporalDecayWeight(elapsedHours: 24.0)
        let weight96h = UserAffinityEngine.temporalDecayWeight(elapsedHours: 96.0)
        let weight360h = UserAffinityEngine.temporalDecayWeight(elapsedHours: 360.0)

        #expect(weight1h > 0.95)
        #expect(weight24h > 0.60 && weight24h < 0.65)
        #expect(weight96h > 0.10 && weight96h < 0.20)
        #expect(weight360h < 0.001)
    }

    @Test("Inverted-U exposure curve saturates and decays at overplay threshold")
    func exposureCurveSaturation() {
        let bonus1 = UserAffinityEngine.exposureBonus(playCount: 1)
        let bonus5 = UserAffinityEngine.exposureBonus(playCount: 5)
        let bonus10 = UserAffinityEngine.exposureBonus(playCount: 10)
        let bonus30 = UserAffinityEngine.exposureBonus(playCount: 30)

        #expect(bonus1 == 15.0)
        #expect(bonus5 == 75.0)
        #expect(bonus10 == 100.0)
        #expect(bonus30 < bonus10) // Decays due to satiation threshold
    }

    @Test("Disliked tracks and artists receive hard suppression (-1000)")
    func dislikeHardSuppression() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let engine = UserAffinityEngine(storageDirectory: tempDir, skipPersistence: true)

        engine.recordPlay(videoId: "vid-bad", artist: "Bad Artist", completed: true)
        engine.recordDislike(videoId: "vid-bad", artist: "Bad Artist")

        let score = engine.computeAffinityScore(videoId: "vid-bad", artist: "Bad Artist")
        #expect(score < 0)
    }

    @Test("Backward-compatible decoding succeeds for legacy JSON profiles")
    func backwardCompatibleDecoding() throws {
        let legacyJSON = """
        {
            "accountScopeID": "test-user",
            "artistScores": {"Eminem": 50},
            "trackPlayCounts": {"em-1": 3},
            "likedVideoIDs": ["em-1"],
            "recentVideoIDs": ["em-1"]
        }
        """

        let decoded = try JSONDecoder().decode(UserAffinityProfile.self, from: Data(legacyJSON.utf8))
        #expect(decoded.accountScopeID == "test-user")
        #expect(decoded.dislikedVideoIDs.isEmpty)
        #expect(decoded.playTimestamps.isEmpty)
        #expect(decoded.shelfOrderSeed == 0)
    }
}
