import Foundation

public enum PrivacySanitizer {
    public static func sanitize(_ input: String) -> String {
        var value = input
        let patterns = [
            #"https?://\S+"#,
            #"(?:^|\s)/(?:Users|home|tmp|var|private|Volumes)/\S+"#,
            #"\bCODEX_BELL_SECRET_[A-Za-z0-9_-]+\b"#,
            #"\bsk-[A-Za-z0-9_-]{6,}\b"#,
            #"\b(?:access[_ -]?token|api[_ -]?key|secret|token)\s*[:=]\s*\S+"#,
            #"\b[0-9a-fA-F]{32,64}\b"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            value = regex.stringByReplacingMatches(in: value, range: range, withTemplate: " [redacted] ")
        }
        value = value.replacingOccurrences(of: "`", with: "")
        if let whitespace = try? NSRegularExpression(pattern: #"\s+"#) {
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            value = whitespace.stringByReplacingMatches(in: value, range: range, withTemplate: " ")
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
