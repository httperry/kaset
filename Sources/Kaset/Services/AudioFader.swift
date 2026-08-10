import Foundation
import WebKit

/// Audio fader service for smooth volume transitions in WKWebView playback.
@MainActor
final class AudioFader {
    static let shared = AudioFader()

    private var activeTimer: Timer?
    private var currentStep: Int = 0
    private var totalSteps: Int = 10
    private var targetVol: Double = 1.0
    private var isFadeIn: Bool = false
    private var onComplete: (@MainActor () -> Void)?

    private init() {}

    /// Fade out volume to zero over specified duration
    func fadeOut(webView: WKWebView?, duration: TimeInterval, completion: @escaping @MainActor () -> Void) {
        guard let webView else {
            completion()
            return
        }

        self.activeTimer?.invalidate()
        self.currentStep = 0
        self.totalSteps = 10
        self.isFadeIn = false
        self.onComplete = completion

        let stepInterval = duration / Double(self.totalSteps)

        self.activeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak webView] _ in
            Task { @MainActor in
                AudioFader.shared.tick(webView: webView)
            }
        }
    }

    /// Fade in volume from zero to target over specified duration
    func fadeIn(webView: WKWebView?, targetVolume: Double = 1.0, duration: TimeInterval, completion: (@MainActor () -> Void)? = nil) {
        guard let webView else {
            completion?()
            return
        }

        self.activeTimer?.invalidate()
        self.currentStep = 0
        self.totalSteps = 10
        self.targetVol = targetVolume
        self.isFadeIn = true
        self.onComplete = completion

        let stepInterval = duration / Double(self.totalSteps)

        self.activeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak webView] _ in
            Task { @MainActor in
                AudioFader.shared.tick(webView: webView)
            }
        }
    }

    private func tick(webView: WKWebView?) {
        self.currentStep += 1
        let progress = Double(self.currentStep) / Double(self.totalSteps)

        let nextVol = self.isFadeIn
            ? min(self.targetVol, self.targetVol * progress)
            : max(0.0, 1.0 - progress)

        let script = "if (document.querySelector('video')) { document.querySelector('video').volume = \(nextVol); }"
        webView?.evaluateJavaScript(script, completionHandler: nil)

        if self.currentStep >= self.totalSteps {
            self.activeTimer?.invalidate()
            self.activeTimer = nil
            let callback = self.onComplete
            self.onComplete = nil
            callback?()
        }
    }
}
