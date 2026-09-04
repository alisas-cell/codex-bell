import Foundation

public enum AppSupportIdentity {
    public static func supportDirectoryName(bundleIdentifier: String?, declaredName: String?) -> String {
        if let declaredName {
            let clean = declaredName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty,
               !clean.contains("/"),
               !clean.contains("\\"),
               !clean.contains("..") {
                return clean
            }
        }
        return "Codex Bell"
    }
}
