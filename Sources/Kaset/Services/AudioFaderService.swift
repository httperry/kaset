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

        var id: String {
            self.rawValue
        }

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

        let durationMs = Int(duration * 1000)
        let exponent = curve == .logarithmic ? 2.0 : 1.0
        let script = """
            (function() {
                const video = document.querySelector('video');
                if (!video) return;
                if (window.__kasetFadeInterval) {
                    clearInterval(window.__kasetFadeInterval);
                    window.__kasetFadeInterval = null;
                }
                const startVol = video.volume;
                const durationMs = \(durationMs);
                const startTime = performance.now();
                window.__kasetFadeInterval = setInterval(() => {
                    const elapsed = performance.now() - startTime;
                    const progress = Math.min(1.0, elapsed / durationMs);
                    const factor = Math.pow(progress, \(exponent));
                    video.volume = Math.max(0.0, startVol * (1.0 - factor));
                    if (progress >= 1.0) {
                        clearInterval(window.__kasetFadeInterval);
                        window.__kasetFadeInterval = null;
                        video.volume = 0.0;
                    }
                }, 16);
            })();
        """
        webView.evaluateJavaScript(script) { _, _ in
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                completion?()
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

        let durationMs = Int(duration * 1000)
        let exponent = curve == .logarithmic ? 2.0 : 1.0
        let target = max(0.0, min(1.0, targetVolume))
        let script = """
            (function() {
                const video = document.querySelector('video');
                if (!video) return;
                if (window.__kasetFadeInterval) {
                    clearInterval(window.__kasetFadeInterval);
                    window.__kasetFadeInterval = null;
                }
                video.volume = 0.0;
                const durationMs = \(durationMs);
                const targetVol = \(target);
                const startTime = performance.now();
                window.__kasetFadeInterval = setInterval(() => {
                    const elapsed = performance.now() - startTime;
                    const progress = Math.min(1.0, elapsed / durationMs);
                    const factor = Math.pow(progress, \(exponent));
                    video.volume = Math.min(targetVol, targetVol * factor);
                    if (progress >= 1.0) {
                        clearInterval(window.__kasetFadeInterval);
                        window.__kasetFadeInterval = null;
                        video.volume = targetVol;
                    }
                }, 16);
            })();
        """
        webView.evaluateJavaScript(script) { _, _ in
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                completion?()
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
