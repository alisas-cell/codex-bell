import Foundation

public enum TaskNameExtractor {
    public static func extract(cwd: String?, prompt: String?) -> TaskIdentity {
        let component = cwd.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Codex"
        let project = prettifyProject(component)
        let task = extractTask(from: prompt ?? "")
        return TaskIdentity(projectName: cap(project, 32), taskName: task.map { cap($0, max(8, 60 - project.count)) })
    }

    public static func sanitizeForSpeech(_ input: String) -> String {
        var text = PrivacySanitizer.sanitize(input)
        let patterns = [
            #"\b[0-9a-fA-F]{12,64}\b"#,
            #"\b(?:branch|sha|commit(?:\s+hash)?|deployment\s+id|token|port)\s*[:=]?\s*\S+"#,
            #"\bcodex/[A-Za-z0-9._/-]+\b"#
        ]
        for pattern in patterns {
            text = replacing(pattern: pattern, in: text, with: " ")
        }
        text = text.replacingOccurrences(of: "[redacted]", with: " ")
        text = text.replacingOccurrences(of: "`", with: "")
        text = replacing(pattern: #"\s+"#, in: text, with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return cap(text, 96)
    }

    private static func extractTask(from rawPrompt: String) -> String? {
        let prompt = sanitizeForSpeech(rawPrompt)
        let lower = prompt.lowercased()

        if prompt.contains("全站") && lower.contains("seo") && (prompt.contains("升级") || lower.contains("upgrade")) {
            return "全站 SEO 升级"
        }
        if lower.contains("seo") && (lower.contains("upgrade") || prompt.contains("升级")) { return "SEO 升级" }
        if lower.contains("update") && (lower.contains("sweep") || prompt.contains("更新")) { return "Update Sweep" }
        if lower.contains("deploy") || prompt.contains("部署") { return "部署" }
        if lower.contains("test") || prompt.contains("测试") { return "测试" }
        return nil
    }

    private static func prettifyProject(_ raw: String) -> String {
        var name = raw
        if let dot = name.firstIndex(of: ".") { name = String(name[..<dot]) }
        name = name.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        name = replacing(pattern: #"\s+"#, in: name, with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "Codex" }
        return name.split(separator: " ").map { token in
            let lower = token.lowercased()
            if lower == "seo" { return "SEO" }
            if lower == "ui" { return "UI" }
            return lower.prefix(1).uppercased() + lower.dropFirst()
        }.joined(separator: " ")
    }

    private static func replacing(pattern: String, in string: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return string }
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        return regex.stringByReplacingMatches(in: string, range: range, withTemplate: replacement)
    }

    private static func cap(_ value: String, _ maxCount: Int) -> String {
        guard value.count > maxCount else { return value }
        let end = value.index(value.startIndex, offsetBy: maxCount)
        return String(value[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
