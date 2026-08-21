import Foundation
import SwiftUI

// MARK: - Collection Extensions

extension Collection {
    /// Safe subscript that returns nil if index is out of bounds.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    /// Formats the time interval as "mm:ss" or "h:mm:ss".
    var formattedDuration: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies a modifier conditionally.
    @ViewBuilder
    func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Applies a modifier if a value is present.
    @ViewBuilder
    func ifLet<Value>(_ value: Value?, transform: (Self, Value) -> some View) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}

// MARK: - URL Extensions

extension URL {
    /// Returns a higher quality YouTube thumbnail URL (544px).
    var highQualityThumbnailURL: URL? {
        guard let host = self.host,
              host.contains("ytimg.com") || host.contains("googleusercontent.com") || host.contains("ggpht.com")
        else {
            return self
        }

        var urlString = self.absoluteString

        // Replace size parameters for higher quality
        urlString = urlString.replacingOccurrences(of: "w60-h60", with: "w544-h544")
        urlString = urlString.replacingOccurrences(of: "w120-h120", with: "w544-h544")
        urlString = urlString.replacingOccurrences(of: "w226-h226", with: "w544-h544")

        return URL(string: urlString)
    }

    /// Returns an ultra high-resolution (1200px+ / 1080p HD) artwork URL for stage backdrops and hero spotlights.
    var ultraHighQualityThumbnailURL: URL? {
        guard let host = self.host,
              host.contains("ytimg.com") || host.contains("googleusercontent.com") || host.contains("ggpht.com")
        else {
            return self
        }

        var urlString = self.absoluteString

        // 1. Google CDN =w...-h... pattern -> =w1200-h1200-l90-rj
        if urlString.contains("googleusercontent.com") || urlString.contains("ggpht.com") {
            if let regex = try? NSRegularExpression(pattern: "=w\\d+-h\\d+[^?#]*") {
                let range = NSRange(location: 0, length: urlString.utf16.count)
                urlString = regex.stringByReplacingMatches(
                    in: urlString,
                    options: [],
                    range: range,
                    withTemplate: "=w1200-h1200-l90-rj"
                )
            }
            // Replace =s... pattern -> =s1200-c-k-c0x00ffffff-no-rj
            if let regex = try? NSRegularExpression(pattern: "=s\\d+[^?#]*") {
                let range = NSRange(location: 0, length: urlString.utf16.count)
                urlString = regex.stringByReplacingMatches(
                    in: urlString,
                    options: [],
                    range: range,
                    withTemplate: "=s1200-c-k-c0x00ffffff-no-rj"
                )
            }
        }

        // 2. YouTube video thumbnail URLs (i.ytimg.com/vi/<id>/...) -> /hq720.jpg
        if urlString.contains("ytimg.com") {
            urlString = urlString.replacingOccurrences(of: "/default.jpg", with: "/hq720.jpg")
            urlString = urlString.replacingOccurrences(of: "/mqdefault.jpg", with: "/hq720.jpg")
            urlString = urlString.replacingOccurrences(of: "/hqdefault.jpg", with: "/hq720.jpg")
            urlString = urlString.replacingOccurrences(of: "/sddefault.jpg", with: "/hq720.jpg")
            if urlString.contains("w60-h60") || urlString.contains("w120-h120") || urlString.contains("w226-h226") || urlString.contains("w544-h544") {
                urlString = urlString.replacingOccurrences(of: "w60-h60", with: "w1200-h1200")
                urlString = urlString.replacingOccurrences(of: "w120-h120", with: "w1200-h1200")
                urlString = urlString.replacingOccurrences(of: "w226-h226", with: "w1200-h1200")
                urlString = urlString.replacingOccurrences(of: "w544-h544", with: "w1200-h1200")
            }
        }

        return URL(string: urlString)
    }
}

// MARK: - String Extensions

extension String {
    /// Returns a truncated version of the string.
    func truncated(to length: Int, trailing: String = "…") -> String {
        if count > length {
            return String(prefix(length)) + trailing
        }
        return self
    }
}

// MARK: - Color Extensions

extension Color {
    /// Creates a Color from a hex string (e.g., "#FF5733" or "FF5733").
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count
        switch length {
        case 6: // RGB
            let red = Double((rgb >> 16) & 0xFF) / 255.0
            let green = Double((rgb >> 8) & 0xFF) / 255.0
            let blue = Double(rgb & 0xFF) / 255.0
            self.init(red: red, green: green, blue: blue)
        case 8: // ARGB
            let red = Double((rgb >> 16) & 0xFF) / 255.0
            let green = Double((rgb >> 8) & 0xFF) / 255.0
            let blue = Double(rgb & 0xFF) / 255.0
            let alpha = Double((rgb >> 24) & 0xFF) / 255.0
            self.init(red: red, green: green, blue: blue, opacity: alpha)
        default:
            return nil
        }
    }
}
