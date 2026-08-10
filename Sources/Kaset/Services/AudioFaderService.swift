import Foundation
import WebKit

/// Advanced audio fading service providing logarithmic volume ramps and smooth playback crossfades.
@MainActor
final class AudioFaderService {
    static let shared = AudioFaderService()

    /// Volume attenuation curve type for audio ramping.
    enum FadeCurve: String, CaseIterable, Identifiable {
        case linear
        case logarithmic

        var id: String { self.rawValue }

        var displayName: String {
            switch self {
            case .linear: "Linear"
            case .logarithmic: "Logarithmic (Natural)"
            }
        }
    }

    private var activeTimer: Timer?
    private var currentStep: Int = 0
    private var totalSteps: Int = 20
    private var initialVolume: Double = 1.0
    private var targetVolume: Double = 0.0
    private var isFadeOut: Bool = true
    private var curve: FadeCurve = .logarithmic
    private var onComplete: (@MainActor () -> Void)?

    private init() {}

    /// Fades volume from current level to zero over specified duration with optional completion handler.
    func fadeOut(
        webView: WKWebView?,
        duration: TimeInterval = 1.0,
        curve: FadeCurve = .logarithmic,
        completion: (@MainActor () -> Void)? = nil
    ) {
        guard let webView else {
            completion?()
            return
        }

        self.cancelActiveFade()
        self.currentStep = 0
        self.totalSteps = max(10, Int(duration * 20))
        self.initialVolume = 1.0
        self.targetVolume = 0.0
        self.isFadeOut = true
        self.curve = curve
        self.onComplete = completion

        let stepInterval = duration / Double(self.totalSteps)

        self.activeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak webView] _ in
            Task { @MainActor in
                AudioFaderService.shared.performFadeStep(webView: webView)
            }
        }
    }

    /// Fades volume in from zero to target volume level over specified duration.
    func fadeIn(
        webView: WKWebView?,
        targetVolume: Double = 1.0,
        duration: TimeInterval = 1.0,
        curve: FadeCurve = .logarithmic,
        completion: (@MainActor () -> Void)? = nil
    ) {
        guard let webView else {
            completion?()
            return
        }

        self.cancelActiveFade()
        self.currentStep = 0
        self.totalSteps = max(10, Int(duration * 20))
        self.initialVolume = 0.0
        self.targetVolume = max(0.0, min(1.0, targetVolume))
        self.isFadeOut = false
        self.curve = curve
        self.onComplete = completion

        let stepInterval = duration / Double(self.totalSteps)

        self.activeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak webView] _ in
            Task { @MainActor in
                AudioFaderService.shared.performFadeStep(webView: webView)
            }
        }
    }

    /// Cancels any active volume fade timer immediately.
    func cancelActiveFade() {
        self.activeTimer?.invalidate()
        self.activeTimer = nil
        let callback = self.onComplete
        self.onComplete = nil
        callback?()
    }

    private func performFadeStep(webView: WKWebView?) {
        self.currentStep += 1
        let progress = Double(self.currentStep) / Double(self.totalSteps)

        let nextVolume: Double
        if self.isFadeOut {
            let factor = Self.calculateFactor(progress: progress, curve: self.curve)
            nextVolume = max(0.0, self.initialVolume * (1.0 - factor))
        } else {
            let factor = Self.calculateFactor(progress: progress, curve: self.curve)
            nextVolume = min(self.targetVolume, self.targetVolume * factor)
        }

        let script = "if (document.querySelector('video')) { document.querySelector('video').volume = \(nextVolume); }"
        webView?.evaluateJavaScript(script, completionHandler: nil)

        if self.currentStep >= self.totalSteps {
            self.activeTimer?.invalidate()
            self.activeTimer = nil
            let callback = self.onComplete
            self.onComplete = nil
            callback?()
        }
    }

    private static func calculateFactor(progress: Double, curve: FadeCurve) -> Double {
        let clamped = max(0.0, min(1.0, progress))
        switch curve {
        case .linear:
            return clamped
        case .logarithmic:
            // Logarithmic volume curve matching human acoustic loudness perception
            return pow(clamped, 2.0)
        }
    }
}
