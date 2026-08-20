//
//  SubtitleFormatter.swift
//  Kaset
//
//  Intelligent 3-tier space priority formatter for card and track subtitles.
//

import AppKit
import Foundation

// MARK: - SubtitleFormatter

/// Formats card and shelf subtitles using content-first space priority.
///
/// Priority Rules:
/// 1. **Tier 1 (Both Fit):** If `Artist · Tag` fits within `availableWidth`, returns `"Artist · Tag"`.
/// 2. **Tier 2 (Artist Fits, Tag Doesn't):** If adding `· Tag` overflows, drops the tag and returns `"Artist"`.
/// 3. **Tier 3 (Artist Overflows):** Returns `"Artist"` so standard `lineLimit(1)` truncates with `...`.
enum SubtitleFormatter {
    /// Formats an artist and optional tag with pixel-accurate font measurement.
    static func format(
        artist: String,
        tag: String?,
        availableWidth: CGFloat,
        font: NSFont = NSFont.systemFont(ofSize: 11, weight: .regular)
    ) -> String {
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let tag = tag?.trimmingCharacters(in: .whitespacesAndNewlines), !tag.isEmpty else {
            return trimmedArtist
        }

        let fullCandidate = "\(trimmedArtist) · \(tag)"
        let fullWidth = Self.measureWidth(of: fullCandidate, font: font)

        // Tier 1: If full candidate fits, show both
        if fullWidth <= availableWidth {
            return fullCandidate
        }

        // Tier 2 & 3: Drop tag completely so the artist name is never sacrificed for a generic tag
        return trimmedArtist
    }

    /// Character-budget based fallback formatter for CLI tools or non-AppKit contexts.
    static func formatWithCharacterBudget(
        artist: String,
        tag: String?,
        maxCharacterLength: Int = 30
    ) -> String {
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let tag = tag?.trimmingCharacters(in: .whitespacesAndNewlines), !tag.isEmpty else {
            return trimmedArtist
        }

        let fullCandidate = "\(trimmedArtist) · \(tag)"
        if fullCandidate.count <= maxCharacterLength {
            return fullCandidate
        }

        return trimmedArtist
    }

    private static func measureWidth(of string: String, font: NSFont) -> CGFloat {
        (string as NSString).size(withAttributes: [.font: font]).width
    }
}
