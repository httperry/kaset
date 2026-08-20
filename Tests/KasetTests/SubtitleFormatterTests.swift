//
//  SubtitleFormatterTests.swift
//  KasetTests
//

import AppKit
import Foundation
import Testing
@testable import Kaset

@Suite("Subtitle Formatter 3-Tier Priority Tests")
struct SubtitleFormatterTests {
    @Test("Tier 1: Shows both artist and tag when space permits")
    func tier1BothFit() {
        let font = NSFont.systemFont(ofSize: 11, weight: .regular)
        let formatted = SubtitleFormatter.format(
            artist: "The Weeknd",
            tag: "Album",
            availableWidth: 200,
            font: font
        )
        #expect(formatted == "The Weeknd · Album")
    }

    @Test("Tier 2: Drops tag completely when adding tag overflows but artist alone fits")
    func tier2DropTagToPreserveArtist() {
        let font = NSFont.systemFont(ofSize: 11, weight: .regular)
        let artist = "Future, Metro Boomin"
        let tag = "Album"

        // Measure artist alone vs full
        let artistWidth = (artist as NSString).size(withAttributes: [.font: font]).width

        // Give just enough width for artist alone, not artist + tag
        let formatted = SubtitleFormatter.format(
            artist: artist,
            tag: tag,
            availableWidth: artistWidth + 5,
            font: font
        )
        #expect(formatted == "Future, Metro Boomin")
    }

    @Test("Tier 3: Returns artist when artist alone exceeds width (delegates to UI lineLimit)")
    func tier3ArtistOverflows() {
        let font = NSFont.systemFont(ofSize: 11, weight: .regular)
        let artist = "Priyadarshan Mahankuda, The Weeknd, Travis Scott"
        let tag = "Album"

        let formatted = SubtitleFormatter.format(
            artist: artist,
            tag: tag,
            availableWidth: 50,
            font: font
        )
        #expect(formatted == artist)
    }

    @Test("Character budget fallback respects length limits")
    func characterBudgetFallback() {
        let fits = SubtitleFormatter.formatWithCharacterBudget(
            artist: "Drake",
            tag: "2024",
            maxCharacterLength: 20
        )
        #expect(fits == "Drake · 2024")

        let dropsTag = SubtitleFormatter.formatWithCharacterBudget(
            artist: "Future, Metro Boomin",
            tag: "Album",
            maxCharacterLength: 22
        )
        #expect(dropsTag == "Future, Metro Boomin")
    }

    @Test("Handles nil or empty tag cleanly")
    func handlesNilOrEmptyTag() {
        let formattedNil = SubtitleFormatter.format(
            artist: "The Weeknd",
            tag: nil,
            availableWidth: 200
        )
        #expect(formattedNil == "The Weeknd")

        let formattedEmpty = SubtitleFormatter.format(
            artist: "The Weeknd",
            tag: "   ",
            availableWidth: 200
        )
        #expect(formattedEmpty == "The Weeknd")
    }
}
