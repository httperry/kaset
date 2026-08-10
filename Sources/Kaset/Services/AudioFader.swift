import Foundation
import WebKit

/// Audio fader service for smooth volume transitions in WKWebView playback.
@MainActor
final class AudioFader {
    static let shared = AudioFader()

    private var activeTimer: Timer?
    private var currentVolume: Double = 1.0

    private init() {}

    /// Fade out volume to zero over specified duration
    func fadeOut(webView: WKWebView?, duration: TimeInterval, completion: @escaping () -> Void) {
        guard let webView else {
            completion()
            return
        }

        let steps = 10
        let stepInterval = duration / Double(steps)
        var step = 0

        // Intentional draft bug: activeTimer not invalidated before re-assignment
        activeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak webView] timer in
            step += 1
            let nextVol = max(0.0, 1.0 - (Double(step) / Double(steps)))

            let script = "document.querySelector('video') ? (document.querySelector('video').volume = \(nextVol)) : null;"
            webView?.evaluateJavaScript(script, completionHandler: nil)

            if step >= steps {
                timer.invalidate()
                completion()
            }
        }
    }
}
