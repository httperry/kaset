//
//  UserAffinityEngine.swift
//  Kaset
//
//  On-device User Taste & Affinity Engine with Machine Learning (Apple Intelligence) integration.
//

import Foundation
import Observation
import os

// MARK: - PlaybackEvent

/// Records a continuous attention weight for a specific playback instance.
struct PlaybackEvent: Codable, Equatable, Sendable {
    var timestamp: Date
    var attentionWeight: Double
}

// MARK: - UserAffinityProfile

/// Persistent snapshot of user listening taste, affinity scores, and interaction telemetry.
struct UserAffinityProfile: Codable, Equatable, Sendable {
    var accountScopeID: String
    var lastSyncedAt: Date?
    var artistScores: [String: Int]
    var genreScores: [String: Int]
    var trackPlayCounts: [String: Int]
    var playTimestamps: [String: [Date]]
    var playbackEvents: [String: [PlaybackEvent]]
    var curatedVideoIDs: Set<String>
    var likedVideoIDs: Set<String>
    var dislikedVideoIDs: Set<String>
    var dislikedArtistIDs: Set<String>
    var skippedVideoIDs: [String: Int]
    var recentVideoIDs: [String]
    var recentAlbumIDs: [String]
    var lastHeroItemID: String?
    var lastBentoPrimaryID: String?
    var shelfOrderSeed: Int

    init(
        accountScopeID: String = "guest",
        lastSyncedAt: Date? = nil,
        artistScores: [String: Int] = [:],
        genreScores: [String: Int] = [:],
        trackPlayCounts: [String: Int] = [:],
        playTimestamps: [String: [Date]] = [:],
        playbackEvents: [String: [PlaybackEvent]] = [:],
        curatedVideoIDs: Set<String> = [],
        likedVideoIDs: Set<String> = [],
        dislikedVideoIDs: Set<String> = [],
        dislikedArtistIDs: Set<String> = [],
        skippedVideoIDs: [String: Int] = [:],
        recentVideoIDs: [String] = [],
        recentAlbumIDs: [String] = [],
        lastHeroItemID: String? = nil,
        lastBentoPrimaryID: String? = nil,
        shelfOrderSeed: Int = 0
    ) {
        self.accountScopeID = accountScopeID
        self.lastSyncedAt = lastSyncedAt
        self.artistScores = artistScores
        self.genreScores = genreScores
        self.trackPlayCounts = trackPlayCounts
        self.playTimestamps = playTimestamps
        self.playbackEvents = playbackEvents
        self.curatedVideoIDs = curatedVideoIDs
        self.likedVideoIDs = likedVideoIDs
        self.dislikedVideoIDs = dislikedVideoIDs
        self.dislikedArtistIDs = dislikedArtistIDs
        self.skippedVideoIDs = skippedVideoIDs
        self.recentVideoIDs = recentVideoIDs
        self.recentAlbumIDs = recentAlbumIDs
        self.lastHeroItemID = lastHeroItemID
        self.lastBentoPrimaryID = lastBentoPrimaryID
        self.shelfOrderSeed = shelfOrderSeed
    }

    enum CodingKeys: String, CodingKey {
        case accountScopeID
        case lastSyncedAt
        case artistScores
        case genreScores
        case trackPlayCounts
        case playTimestamps
        case playbackEvents
        case curatedVideoIDs
        case likedVideoIDs
        case dislikedVideoIDs
        case dislikedArtistIDs
        case skippedVideoIDs
        case recentVideoIDs
        case recentAlbumIDs
        case lastHeroItemID
        case lastBentoPrimaryID
        case shelfOrderSeed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.accountScopeID = try container.decodeIfPresent(String.self, forKey: .accountScopeID) ?? "guest"
        self.lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        self.artistScores = try container.decodeIfPresent([String: Int].self, forKey: .artistScores) ?? [:]
        self.genreScores = try container.decodeIfPresent([String: Int].self, forKey: .genreScores) ?? [:]
        self.trackPlayCounts = try container.decodeIfPresent([String: Int].self, forKey: .trackPlayCounts) ?? [:]

        self.playbackEvents = try container.decodeIfPresent([String: [PlaybackEvent]].self, forKey: .playbackEvents) ?? [:]
        self.curatedVideoIDs = try container.decodeIfPresent(Set<String>.self, forKey: .curatedVideoIDs) ?? []
        let legacyTimestamps = try container.decodeIfPresent([String: [Date]].self, forKey: .playTimestamps) ?? [:]
        for (videoId, dates) in legacyTimestamps where self.playbackEvents[videoId] == nil {
            self.playbackEvents[videoId] = dates.map { PlaybackEvent(timestamp: $0, attentionWeight: 1.0) }
        }
        self.playTimestamps = legacyTimestamps

        self.likedVideoIDs = try container.decodeIfPresent(Set<String>.self, forKey: .likedVideoIDs) ?? []
        self.dislikedVideoIDs = try container.decodeIfPresent(Set<String>.self, forKey: .dislikedVideoIDs) ?? []
        self.dislikedArtistIDs = try container.decodeIfPresent(Set<String>.self, forKey: .dislikedArtistIDs) ?? []
        self.skippedVideoIDs = try container.decodeIfPresent([String: Int].self, forKey: .skippedVideoIDs) ?? [:]
        self.recentVideoIDs = try container.decodeIfPresent([String].self, forKey: .recentVideoIDs) ?? []
        self.recentAlbumIDs = try container.decodeIfPresent([String].self, forKey: .recentAlbumIDs) ?? []
        self.lastHeroItemID = try container.decodeIfPresent(String.self, forKey: .lastHeroItemID)
        self.lastBentoPrimaryID = try container.decodeIfPresent(String.self, forKey: .lastBentoPrimaryID)
        self.shelfOrderSeed = try container.decodeIfPresent(Int.self, forKey: .shelfOrderSeed) ?? 0
    }
}

// MARK: - UserAffinityEngine

/// Engine managing on-device user affinity scoring, temporal decay, intent modeling, and promotional filtering.
@MainActor
@Observable
final class UserAffinityEngine {
    static let shared = UserAffinityEngine()

    /// Ebbinghaus exponential decay rate per hour (half-life ≈ 35 hours)
    static let decayRatePerHour: Double = 0.02

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

    // MARK: - Mathematical & Psychological Models

    /// Calculates exponential temporal decay weight using the Ebbinghaus forgetting curve.
    /// w(t) = e^(-λ * Δt)
    static func temporalDecayWeight(elapsedHours: Double) -> Double {
        exp(-self.decayRatePerHour * max(0, elapsedHours))
    }

    /// Computes Zajonc mere-exposure bonus with an inverted-U saturation curve to prevent permanent over-exposure.
    static func exposureBonus(playCount: Int) -> Double {
        if playCount <= 0 {
            return 0
        }
        if playCount <= 5 {
            return Double(playCount * 15)
        } else if playCount <= 15 {
            return 75.0 + Double((playCount - 5) * 5)
        } else {
            // Satiation threshold decay: prevent 50+ plays from permanently monopolizing Hero
            let overplayDecay = Double((playCount - 15) * 3)
            return max(20.0, 125.0 - overplayDecay)
        }
    }

    /// Computes circadian context multiplier matching current listening time-of-day.
    static func circadianContextMultiplier(currentDate: Date = Date(), targetHour: Int? = nil) -> Double {
        guard let targetHour else { return 1.0 }
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: currentDate)
        let diff = abs(currentHour - targetHour)
        let circularDiff = min(diff, 24 - diff)
        if circularDiff <= 2 {
            return 1.3 // Strong time-of-day match
        } else if circularDiff <= 4 {
            return 1.15
        } else {
            return 1.0
        }
    }

    // MARK: - Telemetry & Interaction Recording

    /// Records a track play event with intent weighting and timestamps.
    func recordPlay(
        videoId: String,
        artist: String? = nil,
        albumId: String? = nil,
        genre: String? = nil,
        listenedSeconds: Double,
        totalSeconds: Double,
        isAutoplay: Bool = false,
        timestamp: Date = Date()
    ) {
        self.profile.trackPlayCounts[videoId, default: 0] += 1

        let ratio = totalSeconds > 0 ? (listenedSeconds / totalSeconds) : 1.0
        let attentionWeight: Double = if ratio < 0.2 {
            -1.0
        } else if ratio <= 0.8 {
            ratio
        } else {
            ratio // Allows > 1.0 for looping
        }

        var events = self.profile.playbackEvents[videoId, default: []]
        events.append(PlaybackEvent(timestamp: timestamp, attentionWeight: attentionWeight))
        if events.count > 30 {
            events = Array(events.suffix(30))
        }
        self.profile.playbackEvents[videoId] = events
        self.profile.playTimestamps[videoId] = events.map(\.timestamp) // For legacy sync

        let intentMultiplier: Double = isAutoplay ? 0.3 : (attentionWeight >= 0.8 ? 2.0 : 1.0)
        let artistIncrement = Int(10.0 * intentMultiplier)
        if let artist = artist?.trimmingCharacters(in: .whitespacesAndNewlines), !artist.isEmpty {
            self.profile.artistScores[artist, default: 0] += artistIncrement
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

    // Records a user like action (explicit high motivation signal).

    /// Records a user deliberately categorizing a track (highest explicit signal).
    func recordPlaylistAdd(videoId: String, artist: String? = nil) {
        self.profile.curatedVideoIDs.insert(videoId)
        if let artist = artist?.trimmingCharacters(in: .whitespacesAndNewlines), !artist.isEmpty {
            self.profile.artistScores[artist, default: 0] += 60
        }
        self.scheduleSave()
    }

    /// Records a user like action (explicit high motivation signal).
    func recordLike(videoId: String, artist: String? = nil) {
        self.profile.likedVideoIDs.insert(videoId)
        self.profile.dislikedVideoIDs.remove(videoId)
        if let artist = artist?.trimmingCharacters(in: .whitespacesAndNewlines), !artist.isEmpty {
            self.profile.artistScores[artist, default: 0] += 50
        }
        self.scheduleSave()
    }

    /// Records a user dislike action (explicit negative rejection signal).
    func recordDislike(videoId: String, artist: String? = nil) {
        self.profile.likedVideoIDs.remove(videoId)
        self.profile.dislikedVideoIDs.insert(videoId)
        if let artist = artist?.trimmingCharacters(in: .whitespacesAndNewlines), !artist.isEmpty {
            self.profile.dislikedArtistIDs.insert(artist)
            self.profile.artistScores[artist] = 0
        }
        self.scheduleSave()
    }

    /// Records a track skip event (negative implicit signal).
    func recordSkip(videoId: String, artist: String? = nil) {
        self.profile.skippedVideoIDs[videoId, default: 0] += 1
        if let artist = artist?.trimmingCharacters(in: .whitespacesAndNewlines), !artist.isEmpty {
            let current = self.profile.artistScores[artist, default: 0]
            self.profile.artistScores[artist] = max(0, current - 5)
        }
        self.scheduleSave()
    }

    /// Records the Hero item ID shown on the screen to support anti-habituation rotation.
    func recordHeroShown(itemId: String) {
        self.profile.lastHeroItemID = itemId
        self.profile.shelfOrderSeed = (self.profile.shelfOrderSeed + 1) % 10000
        self.scheduleSave()
    }

    /// Records the Bento primary item ID shown to support anti-habituation rotation.
    func recordBentoPrimaryShown(itemId: String) {
        self.profile.lastBentoPrimaryID = itemId
        self.scheduleSave()
    }

    /// Returns the affinity score for a given artist name.
    func affinityScore(forArtist artist: String) -> Int {
        let trimmed = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        if self.profile.dislikedArtistIDs.contains(trimmed) {
            return 0
        }
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

    /// Computes the comprehensive behavioral composite affinity score for an item.
    /// Incorporates: Ebbinghaus temporal decay, Zajonc exposure curve, Fogg intent hierarchy, and negative suppression.
    func computeAffinityScore(
        videoId: String?,
        artist: String?,
        albumId: String? = nil,
        referenceDate: Date = Date()
    ) -> Double {
        // 1. Negative Signal: Hard suppression
        if let videoId, self.profile.dislikedVideoIDs.contains(videoId) {
            return -1000.0
        }
        if let artist {
            let cleanArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
            if self.profile.dislikedArtistIDs.contains(cleanArtist) {
                return -1000.0
            }
        }

        var compositeScore = 0.0

        if let videoId {
            // 2. ACT-R Base-Level Activation (Power Law & Attention Weighting)
            var baseActivation = 0.0
            if let events = self.profile.playbackEvents[videoId], !events.isEmpty {
                for event in events {
                    let hoursSince = max(0.1, referenceDate.timeIntervalSince(event.timestamp) / 3600.0)
                    baseActivation += event.attentionWeight * pow(hoursSince, -0.5) // d = 0.5 ACT-R Decay
                }
            } else if let count = self.profile.trackPlayCounts[videoId], count > 0 {
                // Fallback for untimestamped history
                baseActivation = Double(count) * 0.5
            }

            // 3. Spreading Activation (System 2 Intent Permastore)
            let isCurated = self.profile.curatedVideoIDs.contains(videoId)
            let isLiked = self.profile.likedVideoIDs.contains(videoId)
            let spreadingActivation: Double = (isCurated ? 25.0 : 0.0) + (isLiked ? 15.0 : 0.0)

            // Replaces the old sum of exponential decays and exposure bonus
            compositeScore += (baseActivation * 25.0) + (spreadingActivation * 25.0) // Scaled for UI sorting

            // 4. Skip penalty (-10 per skip)
            if let skips = self.profile.skippedVideoIDs[videoId], skips > 0 {
                compositeScore -= Double(skips * 10)
            }
        }

        // 6. Artist affinity with decay
        if let artist {
            let rawArtistScore = Double(self.affinityScore(forArtist: artist))
            compositeScore += rawArtistScore * 0.4
        }

        // 7. Recent album bonus
        if let albumId, let albumRecentIndex = self.profile.recentAlbumIDs.firstIndex(of: albumId) {
            if albumRecentIndex < 3 {
                compositeScore += 25.0
            } else if albumRecentIndex < 10 {
                compositeScore += 10.0
            }
        }

        return max(0, compositeScore)
    }

    // MARK: - Cloud Delta Reconciliation

    /// Reconciles local profile with cloud history from YouTube Music using time bucket and chronological positional decay.
    func reconcileWithCloudHistory(historySections: [HomeSection], referenceDate: Date = Date()) {
        var globalIndex = 0
        for section in historySections {
            let lowerTitle = section.title.lowercased()
            let isToday = lowerTitle.contains("today")
            let isYesterday = lowerTitle.contains("yesterday")
            let isThisWeek = lowerTitle.contains("this week") || lowerTitle.contains("earlier this week")
            let isEarlier = lowerTitle.contains("earlier") || lowerTitle.contains("last week") || lowerTitle.contains("last month")
            let hasKnownBucket = isToday || isYesterday || isThisWeek || isEarlier

            for item in section.items {
                let hourOffset = if hasKnownBucket {
                    if isToday {
                        2.0
                    } else if isYesterday {
                        26.0
                    } else if isThisWeek {
                        96.0
                    } else {
                        360.0
                    }
                } else {
                    // Chronological positional decay when YouTube returns unbucketed shelves
                    if globalIndex < 5 {
                        1.0 + Double(globalIndex) * 0.5
                    } else if globalIndex < 20 {
                        10.0 + Double(globalIndex - 5) * 1.0
                    } else if globalIndex < 50 {
                        25.0 + Double(globalIndex - 20) * 2.0
                    } else {
                        85.0 + Double(globalIndex - 50) * 4.0
                    }
                }
                globalIndex += 1

                let approximateTimestamp = referenceDate.addingTimeInterval(-hourOffset * 3600.0)

                switch item {
                case let .song(song):
                    self.recordPlay(
                        videoId: song.videoId,
                        artist: song.artistsDisplay,
                        albumId: song.album?.id,
                        listenedSeconds: 100.0,
                        totalSeconds: 100.0,
                        timestamp: approximateTimestamp
                    )
                case let .album(album):
                    let artistName = album.artistsDisplay
                    if !artistName.isEmpty {
                        let decay = Self.temporalDecayWeight(elapsedHours: hourOffset)
                        self.profile.artistScores[artistName, default: 0] += Int(20.0 * decay)
                    }
                    self.profile.recentAlbumIDs.removeAll { $0 == album.id }
                    self.profile.recentAlbumIDs.insert(album.id, at: 0)
                case .playlist, .artist:
                    break
                }
            }
        }
        self.profile.lastSyncedAt = referenceDate
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

        let matchingCount = items.filter { item in
            guard let sub = item.subtitle?.lowercased() else { return false }
            return sub.contains(lower)
        }.count

        return matchingCount >= max(1, items.count / 2)
    }

    /// Generates a dynamic editorial summary for the Hero spotlight based on time of day.
    func generateHeroEditorialDescription(title _: String, artistSummary: String, currentDate: Date = Date()) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentDate)

        let timeContext = if hour >= 5, hour < 12 {
            "Your morning rotation & energizing mixes"
        } else if hour >= 12, hour < 18 {
            "Your daytime soundtrack & focus picks"
        } else if hour >= 18, hour < 22 {
            "Your evening rotation & favorite discoveries"
        } else {
            "Your late-night rotation & deep cuts"
        }

        if !artistSummary.isEmpty {
            return "\(timeContext), featuring \(artistSummary)."
        }
        return "\(timeContext) tailored for you today."
    }
}
