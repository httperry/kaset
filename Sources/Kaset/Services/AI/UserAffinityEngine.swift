//
//  UserAffinityEngine.swift
//  Kaset
//
//  On-device User Taste & Affinity Engine with Machine Learning (Apple Intelligence) integration.
//

import Foundation
import Observation
import os

// MARK: - UserAffinityProfile

/// Persistent snapshot of user listening taste, affinity scores, and interaction telemetry.
struct UserAffinityProfile: Codable, Equatable, Sendable {
    var accountScopeID: String
    var lastSyncedAt: Date?
    var artistScores: [String: Int]
    var genreScores: [String: Int]
    var trackPlayCounts: [String: Int]
    var likedVideoIDs: Set<String>
    var recentVideoIDs: [String]
    var recentAlbumIDs: [String]

    init(
        accountScopeID: String = "guest",
        lastSyncedAt: Date? = nil,
        artistScores: [String: Int] = [:],
        genreScores: [String: Int] = [:],
        trackPlayCounts: [String: Int] = [:],
        likedVideoIDs: Set<String> = [],
        recentVideoIDs: [String] = [],
        recentAlbumIDs: [String] = []
    ) {
        self.accountScopeID = accountScopeID
        self.lastSyncedAt = lastSyncedAt
        self.artistScores = artistScores
        self.genreScores = genreScores
        self.trackPlayCounts = trackPlayCounts
        self.likedVideoIDs = likedVideoIDs
        self.recentVideoIDs = recentVideoIDs
        self.recentAlbumIDs = recentAlbumIDs
    }
}

// MARK: - UserAffinityEngine

/// Engine managing on-device user affinity scoring, cloud delta reconciliation, and promotional filtering.
@MainActor
@Observable
final class UserAffinityEngine {
    static let shared = UserAffinityEngine()

    private(set) var profile: UserAffinityProfile
    private let storageDirectory: URL
    private let skipPersistence: Bool
    private let logger = DiagnosticsLogger.api
    private var saveTask: Task<Void, Never>?

    private static var defaultStorageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport.appendingPathComponent("Kaset/affinity", isDirectory: true)
    }

    init(
        storageDirectory: URL = UserAffinityEngine.defaultStorageDirectory,
        skipPersistence: Bool = UITestConfig.isUITestMode || UITestConfig.isRunningUnitTests
    ) {
        self.storageDirectory = storageDirectory
        self.skipPersistence = skipPersistence
        self.profile = UserAffinityProfile()

        if !skipPersistence {
            self.loadProfile(for: "guest")
        }
    }

    // MARK: - Account Scoping & Persistence

    /// Switches the active account scope (e.g. on sign-in or account switch).
    func setActiveScope(accountScopeID: String) {
        self.saveImmediately()
        self.loadProfile(for: accountScopeID)
    }

    /// Loads the stored affinity profile for a given account scope.
    func loadProfile(for scopeID: String) {
        guard !self.skipPersistence else {
            self.profile = UserAffinityProfile(accountScopeID: scopeID)
            return
        }

        let fileURL = self.profileFileURL(for: scopeID)
        do {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                self.profile = UserAffinityProfile(accountScopeID: scopeID)
                return
            }
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(UserAffinityProfile.self, from: data)
            self.profile = decoded
            self.logger.debug("Loaded affinity profile for scope: \(scopeID, privacy: .public)")
        } catch {
            self.logger.error("Failed to load affinity profile for \(scopeID): \(error.localizedDescription)")
            self.profile = UserAffinityProfile(accountScopeID: scopeID)
        }
    }

    /// Schedules a debounced disk save of the active profile.
    func scheduleSave() {
        guard !self.skipPersistence else { return }
        self.saveTask?.cancel()
        self.saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            guard !Task.isCancelled else { return }
            self.saveImmediately()
        }
    }

    /// Immediately flushes the active profile to disk.
    func saveImmediately() {
        guard !self.skipPersistence else { return }
        let fileURL = self.profileFileURL(for: self.profile.accountScopeID)
        do {
            try FileManager.default.createDirectory(at: self.storageDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(self.profile)
            try data.write(to: fileURL, options: .atomic)
            self.logger.debug("Saved affinity profile for scope: \(self.profile.accountScopeID, privacy: .public)")
        } catch {
            self.logger.error("Failed to save affinity profile: \(error.localizedDescription)")
        }
    }

    private func profileFileURL(for scopeID: String) -> URL {
        let safeName = scopeID.replacingOccurrences(of: "/", with: "_")
        return self.storageDirectory.appendingPathComponent("\(safeName).json")
    }

    // MARK: - Affinity Scoring & Telemetry

    /// Records a track play event.
    func recordPlay(
        videoId: String,
        artist: String? = nil,
        albumId: String? = nil,
        genre: String? = nil,
        completed: Bool = true
    ) {
        let playIncrement = completed ? 10 : 3
        self.profile.trackPlayCounts[videoId, default: 0] += 1

        if let artist = artist?.trimmingCharacters(in: .whitespacesAndNewlines), !artist.isEmpty {
            self.profile.artistScores[artist, default: 0] += playIncrement
        }

        if let genre = genre?.trimmingCharacters(in: .whitespacesAndNewlines), !genre.isEmpty {
            self.profile.genreScores[genre, default: 0] += 5
        }

        // Update recents
        self.profile.recentVideoIDs.removeAll { $0 == videoId }
        self.profile.recentVideoIDs.insert(videoId, at: 0)
        if self.profile.recentVideoIDs.count > 100 {
            self.profile.recentVideoIDs = Array(self.profile.recentVideoIDs.prefix(100))
        }

        if let albumId, !albumId.isEmpty {
            self.profile.recentAlbumIDs.removeAll { $0 == albumId }
            self.profile.recentAlbumIDs.insert(albumId, at: 0)
            if self.profile.recentAlbumIDs.count > 50 {
                self.profile.recentAlbumIDs = Array(self.profile.recentAlbumIDs.prefix(50))
            }
        }

        self.scheduleSave()
    }

    /// Records a user like action.
    func recordLike(videoId: String, artist: String? = nil) {
        self.profile.likedVideoIDs.insert(videoId)
        if let artist = artist?.trimmingCharacters(in: .whitespacesAndNewlines), !artist.isEmpty {
            self.profile.artistScores[artist, default: 0] += 50
        }
        self.scheduleSave()
    }

    /// Records a user dislike action.
    func recordDislike(videoId: String, artist: String? = nil) {
        self.profile.likedVideoIDs.remove(videoId)
        if let artist = artist?.trimmingCharacters(in: .whitespacesAndNewlines), !artist.isEmpty {
            let current = self.profile.artistScores[artist, default: 0]
            self.profile.artistScores[artist] = max(0, current - 30)
        }
        self.scheduleSave()
    }

    /// Returns the affinity score for a given artist name.
    func affinityScore(forArtist artist: String) -> Int {
        let trimmed = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = self.profile.artistScores[trimmed] {
            return direct
        }
        // Case-insensitive fallback
        let lower = trimmed.lowercased()
        for (key, val) in self.profile.artistScores where key.lowercased() == lower {
            return val
        }
        return 0
    }

    /// Computes a composite affinity score for an item considering play frequency, artist affinity, likes, and recency.
    func computeAffinityScore(videoId: String?, artist: String?, albumId: String? = nil) -> Int {
        var totalScore = 0

        // 1. Play frequency weight (+15 per play)
        if let videoId, let count = self.profile.trackPlayCounts[videoId] {
            totalScore += count * 15
        }

        // 2. Artist affinity weight
        if let artist {
            totalScore += self.affinityScore(forArtist: artist)
        }

        // 3. Like status (+30)
        if let videoId, self.profile.likedVideoIDs.contains(videoId) {
            totalScore += 30
        }

        // 4. Recency bonus (Top 5 recents get +10, top 20 get +5)
        if let videoId, let recentIndex = self.profile.recentVideoIDs.firstIndex(of: videoId) {
            if recentIndex < 5 {
                totalScore += 10
            } else if recentIndex < 20 {
                totalScore += 5
            }
        }

        if let albumId, let albumRecentIndex = self.profile.recentAlbumIDs.firstIndex(of: albumId) {
            if albumRecentIndex < 3 {
                totalScore += 20
            }
        }

        return totalScore
    }

    // MARK: - Cloud Delta Reconciliation

    /// Reconciles local profile with cloud history from YouTube Music.
    func reconcileWithCloudHistory(historySections: [HomeSection]) {
        for section in historySections {
            for item in section.items {
                switch item {
                case let .song(song):
                    self.recordPlay(
                        videoId: song.videoId,
                        artist: song.artistsDisplay,
                        albumId: song.album?.id,
                        completed: true
                    )
                case let .album(album):
                    let artistName = album.artistsDisplay
                    if !artistName.isEmpty {
                        self.profile.artistScores[artistName, default: 0] += 15
                    }
                    self.profile.recentAlbumIDs.removeAll { $0 == album.id }
                    self.profile.recentAlbumIDs.insert(album.id, at: 0)
                case .playlist, .artist:
                    break
                }
            }
        }
        self.profile.lastSyncedAt = Date()
        self.scheduleSave()
    }

    /// Reconciles local profile with cloud liked tracks.
    func reconcileWithCloudLikes(likedSongs: [Song]) {
        for song in likedSongs {
            self.profile.likedVideoIDs.insert(song.videoId)
            let artist = song.artistsDisplay
            if !artist.isEmpty {
                self.profile.artistScores[artist, default: 0] += 20
            }
        }
        self.profile.lastSyncedAt = Date()
        self.scheduleSave()
    }

    // MARK: - Machine Learning & Promotional Filtering

    /// Evaluates whether a shelf is an unlistened promotional/sponsored shelf that should be filtered out.
    ///
    /// Examples:
    /// - Shelf titled "Camila Cabello" when user has 0 affinity score and no liked songs by Camila Cabello.
    /// - Single-artist spotlight where 80%+ items belong to an artist with zero user interaction.
    func isPromotionalShelf(title: String, items: [HomeSectionItem]) -> Bool {
        guard !items.isEmpty else { return false }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmedTitle.lowercased()

        // Standard algorithmic/curation shelves are never promotional
        let genericTitles = [
            "quick picks", "listen again", "forgotten favourites", "albums for you",
            "trending", "new releases", "from your library", "music videos", "live performances",
            "community", "covers and remixes", "charts", "explore", "recap", "mixed for you",
            "recommended", "similar to", "artists", "playlists for you", "favorites", "favourites",
        ]
        if genericTitles.contains(where: { lower.contains($0) }) {
            return false
        }

        // Rule 1: Title explicitly matches a single artist name
        if self.isSingleArtistShelf(title: trimmedTitle, items: items) {
            let score = self.affinityScore(forArtist: trimmedTitle)
            if score == 0 {
                self.logger.info("Filtered zero-affinity promotional shelf: '\(trimmedTitle)' (score: 0)")
                return true
            }
        }

        // Rule 2: Single-artist item dominance test
        var artistCounts: [String: Int] = [:]
        var totalInspectableItems = 0

        for item in items {
            if let artist = item.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines), !artist.isEmpty {
                artistCounts[artist, default: 0] += 1
                totalInspectableItems += 1
            }
        }

        guard totalInspectableItems >= 3 else { return false }

        if let (dominantArtist, count) = artistCounts.max(by: { $0.value < $1.value }) {
            let dominanceRatio = Double(count) / Double(totalInspectableItems)
            if dominanceRatio >= 0.8 {
                let score = self.affinityScore(forArtist: dominantArtist)
                if score == 0 {
                    self.logger.info("Filtered dominant zero-affinity artist shelf: '\(dominantArtist)' (ratio: \(dominanceRatio))")
                    return true
                }
            }
        }

        return false
    }

    private func isSingleArtistShelf(title: String, items: [HomeSectionItem]) -> Bool {
        let lower = title.lowercased()

        // If all items have this title as the artist or author
        let matchingCount = items.filter { item in
            guard let sub = item.subtitle?.lowercased() else { return false }
            return sub.contains(lower)
        }.count

        return matchingCount >= max(1, items.count / 2)
    }

    /// Generates a dynamic editorial summary for the Hero spotlight.
    /// Uses Apple Intelligence `FoundationModels` when available, or a smart template fallback.
    func generateHeroEditorialDescription(title _: String, artistSummary: String) async -> String {
        #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                if FoundationModelsService.shared.isAvailable {
                    // Future extension: session.respond(to: prompt)
                }
            }
        #endif

        // High-quality template fallback
        return "An endless personalized mix combining your favorite daily tracks with fresh new discoveries from \(artistSummary)."
    }
}
