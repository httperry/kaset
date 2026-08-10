import Testing
@testable import Kaset

// MARK: - AudioFaderServiceTests

@MainActor
struct AudioFaderServiceTests {
    @Test("Default fader instance is accessible")
    func defaultFaderInstance() {
        let fader = AudioFaderService.shared
        #expect(fader.idForTesting == "AudioFaderService.shared")
    }

    @Test("FadeCurve displayName values are non-empty")
    func fadeCurveDisplayNames() {
        for curve in AudioFaderService.FadeCurve.allCases {
            #expect(!curve.displayName.isEmpty)
            #expect(!curve.id.isEmpty)
        }
    }
}

extension AudioFaderService {
    var idForTesting: String {
        "AudioFaderService.shared"
    }
}
